#!/usr/bin/env python3

import os
from enum import Enum

import signal
import subprocess

import platform

import concurrent.futures

import time

# click and psutil require pip install

# cli handling
import click

# command line arg parsing for atlas
import re

# TODO: this won't run after install on Windows for me, fine on Mac
# for physical core count to limit spawns
#import psutil

class TextureContent(Enum):
	Unknown = 0
	Albedo = 1
	Normal = 2
	SDF = 3
	MetalRoughness = 4
	Mask = 5
	Height = 6

class TextureType(Enum):
	Unknown = 0
	Tex2D = 1
	Tex3D = 2
	Cube = 3
	Tex1DArray = 4
	Tex2DArray = 5
	CubeArray = 6
	
class TextureProcessor:
	# platform to create texture for
	platform = ""

	appKram = ""

	appKtx2 = ""
	appKtx2sc = ""
	appKtx2check = ""
	doUastc = False
	doKTX2 = False
	
	# preset formats for a given platform
	textureFormats = []

	# how many physical cores to use
	maxCores = 1

	# don't regenerate the file if modstamp of output is newer than source
	skipIfSameModstamp = True

	# Generate commands and execute them inside kram.  This would scale to gpu better.
	doScript = False
	scriptFilename = ""
	scriptFile = "" # really a File object

	# so script can be killed
	doExit = False

	def __init__(self, platform, appKram, maxCores, force, script, scriptFilename, textureFormats):
		self.platform = platform

		self.appKram = appKram
		self.textureFormats = textureFormats

		if script:
			self.doScript = True
			self.scriptFilename = scriptFilename
			os.makedirs(os.path.dirname(scriptFilename), exist_ok = True)
			self.scriptFile = open(scriptFilename, "w")

		self.maxCores = maxCores
		if force:
			self.skipIfSameModstamp = False

	# convert filename to texture type
	def textureContent(self, name):
		name = name.lower()
		content = TextureContent.Unknown

		# TODO: could read metadata out of src png/ktx files with content/kind
		# and then can avoid mangling the names

		if name.endswith("-metal"):
			content = TextureContent.MetalRoughness
		elif name.endswith("-mask"):
			content = TextureContent.Mask
		elif name.endswith("-sdf"):
			content = TextureContent.SDF
		elif name.endswith("-a") or name.endswith("-albedo"):
			content = TextureContent.Albedo
		elif name.endswith("-n") or name.endswith("-normal"):
			content = TextureContent.Normal
		elif name.endswith("-h") or name.endswith("-height"):
			content = TextureContent.Height

		return content

	# convert filename to texture kind
	def textureType(self, name):
		name = name.lower()
	
		# assume 2d texture for everything
		kind = TextureType.Tex2D;

		if ("-3d" in name):
			kind = TextureType.Tex3D
		elif ("-cube" in name):
			kind = TextureType.Cube
		
		elif ("-1darray" in name):
			kind = TextureType.Tex1DArray
		elif ("-2darray" in name):
			kind = TextureType.Tex2DArray
		elif ("-cubearray" in name):
			kind = TextureType.CubeArray
			
		return kind

	def parseAtlasChunks(self, name):
		name = name.lower()
	
		# assume 2d texture for everything
		chunksX = 0
		chunksY = 0

		if ("-atlas" in name):
			match = re.search(r"-atlas\d+x\d+", name)
			if match: 
				nums = re.findall(r'\d+', match.group())

				chunksX = int(nums[0])
				chunksY = int(nums[1])
				
		return chunksX, chunksY

	def spawn(self, command):
		print("running " + command)
		
		retval = subprocess.call(command, shell=True)
		if retval != 0:
			print("cmd: failed " + command)
			return 1
		
		return 0

	def processTextureKram(self, srcPath, dstDir, srcModstamp): 
		# skip unrecognized extensions in the folder
		srcRoot, srcExtension = os.path.splitext(srcPath)
		srcExtension = srcExtension.lower()
		if not (srcExtension == ".png" or srcExtension == ".ktx" or srcExtension == ".ktx2"):
			if not srcPath.endswith(".DS_Store"):
				print("skipping unknown extension on file {0}".format(srcPath))
			return 0
		
		srcFilename = os.path.basename(srcRoot) # just the name no ext

		ext = ".ktx"
		if self.doKTX2:
			ext = ".ktx2"
		dstName = srcFilename 

		# replace -h with -n, since it will be converted to a normal
		if dstName.endswith("-h"):
			dstName = dstName.replace("-h", "-n")

		dstName += ext

		dstFile = dstDir + dstName

		# check the modstamp of src vs. dst output, form same name at dstPath, and check os.stat() on that
		if self.skipIfSameModstamp and os.path.exists(dstFile) and (os.stat(dstFile).st_mtime_ns > srcModstamp):
			return 0
	
		content = self.textureContent(srcRoot)

		# skip any content that don't have format
		fmt = self.textureFormats[content.value]
		if not fmt:
			return 0

		# turn off mips if don't know content type
		#if content == TextureContent.Unknown:
		#	fmt += " -mipnone"

		# DONE: handle more texture types (cube, array, etc).  Use naming convention for that.
		# split these up off name + strip textures, can figure out most of atlasing from that and pow2.
		# if it's an altas containing smaller tiles in rows, then may need to supply tile size/count
		# and possibly horizontal vs. vertical atlasing.  Count more general since it applies even after dropping mips.
		# app currently assumes smaller dimension.  Can spawn out to kram info to get width and height.

		texType = self.textureType(srcRoot)

		switcher = {
			TextureType.Tex2D: " -type 2d",
			TextureType.Tex3D: " -type 3d -mipnone", # mips unsupported
			TextureType.Cube: " -type cube",
			
			# 1d array - no compression or mips, on M1 fails with compression, but not on Intel/AMD, use 2d array instead
			# will likely strip this as a supported type
			TextureType.Tex1DArray: " -type 1darray -mipnone -f rgba8",
			TextureType.Tex2DArray: " -type 2darray",
			TextureType.CubeArray: " -type cubearray",
		}
		typeText = switcher.get(texType, " -type 2d")

		# choice of none, zlib, or zstd
		compressorText = ""
		if self.doKTX2:
			compressorText = " -zstd 0"

		# this could work on 3d and cubearray textures, but for now only use on 2D textures
		chunksText = ""
		if texType == TextureType.Tex2DArray:
			chunksX, chunksY = self.parseAtlasChunks(srcRoot)
			if chunksX > 0 and chunksY > 0:
				chunksText = " -chunks {0}x{1}".format(chunksX, chunksY)

		cmd = "encode" + fmt + typeText + chunksText + compressorText + " -i " + srcPath + " -o " + dstFile

		# can print out commands to script and then process that all in C++
		if self.doScript:
			self.scriptFile.write(cmd)
			self.scriptFile.write('\n')
			result = 0

		else:
			timer = -time.perf_counter()
		
			# kram can't compress to uastc ktx2, but this script can via ktx2sc from original file
			result = self.spawn(self.appKram + " " + cmd)

			# report slow textures
			slowTextureTime = 1 # 1sec
			timer += time.perf_counter()
			if timer > slowTextureTime:
				print("perf: encode {0} took {1:.3f}s".format(dstName, timer))

			
			# TODO: split this off into another modstamp testing pass, and only do work if ktx is older than ktx2
			# convert ktx -> ktx2, and zstd supercompress the mips, kram can read these and decompress
			# for now, this is only possible when not scripted
			# could read these in kram, and then execute them, or write these to another file
			# and then execute that if script file suceeds
			# if self.appKtx2:
			# 	ktx2Filename = dstFile + "2"
				
			# 	# create the ktx2
			# 	result = self.spawn(self.appKtx2 + " -f -o " + ktx2Filename + " " + dstFile)
				
			# 	# too bad this can't check ktx1...
			# 	if self.appKtx2check != "" and result == 0:
			# 		result = self.spawn(self.appKtx2check + " -q " + ktx2Filename)

			# 	# can only zstd compress block encoded files, but can do BasisLZ on 
			# 	#   explicit files.

			# 	# overwrite it with supercompressed version
			# 	# basis uastc supercompress - only if content isn't already block encoded, TODO: kramv and loader cannot read this
			# 	# zstd supercompress - works on everything, kramv and loader can read this
			# 	if self.appKtx2sc != "" and result == 0:
			# 		if self.doUastc:
			# 			result = self.spawn(self.appKtx2sc + " --uastc 2 --uastc_rdo_q 1.0 --zcmp 3 --threads 1 " + ktx2Filename)
			# 		else:
			# 			result = self.spawn(self.appKtx2sc + " --zcmp 3 --threads 1 " + ktx2Filename)

			if self.doKTX2:
				ktx2Filename = dstFile
				
				# double check supercompressed version, may not be necessary
				if self.appKtx2check != "" and result == 0:
			 		result = self.spawn(self.appKtx2check + " -q " + ktx2Filename)
			

		return result

	def scandirRecursively(self, path):
	    for entry in os.scandir(path):
	        if entry.is_dir(follow_symlinks=True):
	            yield from self.scandirRecursively(entry.path)
	        else:
	            yield entry

	def processTexturesKram(self, srcDir, dstDir):
		workData = []
		for entry in self.scandirRecursively(srcDir):
			if entry.is_file():   # also is_dir()
				srcModstamp = entry.stat().st_mtime_ns
				srcPath = entry.path
				workData.append((self, [srcPath, dstDir, srcModstamp]))

		if self.doScript:
			for data in workData:
				self.processTextureKram(data[1][0], data[1][1], data[1][2])

			return 0

		else:
			return self.processTexturesInParallel(workData)

	def processScriptKram(self):
		self.scriptFile.close()

        # Win can't compile psutil, so go back to logical count
        # psutil.cpu_count(logical = False)
		physicalCores = os.cpu_count()
        
		numWorkers = physicalCores
		numWorkers = min(numWorkers, self.maxCores) 

		cmd = self.appKram + " script -v -j " + str(numWorkers) + " -i " + self.scriptFilename

		return self.spawn(cmd)

	def processTexturesInParallel(self, workData):
		
		# ---------------------------
		# now process all the work in parallel

        # Win can't compile psutil, so go back to logical count
        # psutil.cpu_count(logical = False)
		physicalCores = os.cpu_count()
        
		numWorkers = physicalCores
		numWorkers = min(numWorkers, self.maxCores) 
		
		self.doExit = False

		# to avoid pickling issues used multiprocessing.dummy which uses ThreadPool, 
		# ended up routing through this def call which then marshals the args
		def runMapInParallel(args):
			# allow script to be killed, or else workers keep spawning and only one worker is killed by ctrl+c
			# https://stackoverflow.com/questions/11312525/catch-ctrlc-sigint-and-exit-multiprocesses-gracefully-in-python
			# this doesn't work
			if args[0].doExit:
			 	return 0

			try:
				return args[0].processTextureKram(args[1][0], args[1][1], args[1][2]) 
			
			except (KeyboardInterrupt, SystemExit):
				args[0].doExit = True
				print("Exiting...")
				return 1
	            
		# This is the py3.2 way, can use threads or multiprocess (ProcessPoolExecutor)
		numFailures = 0
		
		with concurrent.futures.ThreadPoolExecutor(max_workers=numWorkers) as executor:
			results = executor.map(runMapInParallel, workData)

			for r in results:
				# print(r)
				numFailures += int(r)
	
		if numFailures > 0:
			return 1
		return 0

@click.command()
@click.option('-p', '--platform', type=click.Choice(['ios', 'mac', 'win', 'android', 'any']), required=True, help="build platform")
@click.option('-c', '--container', type=click.Choice(['ktx', 'ktx2']), default="ktx2", help="container type")
@click.option('-v', '--verbose', is_flag=True, help="verbose output")
@click.option('-q', '--quality', default=49, type=click.IntRange(0, 100), help="quality affects encode speed")
@click.option('-j', '--jobs', default=64, help="max physical cores to use")
@click.option('--force', is_flag=True, help="force rebuild ignoring modstamps")
@click.option('--script', is_flag=True, help="generate kram script and execute that")
@click.option('--check', is_flag=True, help="check ktx2 files when generated")
@click.option('--bundle', is_flag=True, help="bundle files by updating a zip file")
def processTextures(platform, container, verbose, quality, jobs, force, script, check, bundle):
	# output to multiple dirs by type

	# eventually pass these in as strings, so script is generic
	# Mac can handle this, but Win want's absolute path (or kram run from PATH)
	binDir = "../bin/"
	appKram = os.path.abspath(binDir + "kram")
	
	appKtx2 = ""
	appKtx2sc = ""
	appKtx2check = ""
	doUastc = False

	ktx2 = True
	if container == "ktx":
		ktx2 = False

	# can convert ktx -> ktx2 files with zstd and Basis supercompression
	# caller must have ktx2ktx2 and ktx2sc in path build from https://github.com/KhronosGroup/KTX-Software
	if platform == "any":
		ktx2 = True
		doUastc = True

	if ktx2:
		# have to run check script after generating, or have to convert ktx to ktx2
		# so that's why these disable scripting
		if doUastc or check:
			script = False

		# these were for converting ktx output from kram to ktx2, and for uastc from original png
		appKtx2 = "ktx2ktx2"
		appKtx2sc ="ktxsc"

		# this is a validator app
		if check:
			appKtx2check = "ktx2check"
	
	# abspath strips the trailing slash off - ugh
	srcDirBase = os.path.abspath("../tests/src/")
	srcDirBase += "/"

	dstDirBase = os.path.abspath("../tests/out/")
	dstDirBase += "/"

	dstDirForPlatform = dstDirBase + platform + "/"
	
	scriptFile = dstDirForPlatform + "kramscript.txt"
	
	# can process multiple src folders, and skip some
	srcDirs = [""]

	maxCores = jobs

	#------------------------------------------
	# TODO: allow multiple platforms to be built in one call

	# Note: need a script per file with more info than just the filename
	# to really set kind and other data.  This is just a simple example script.

	# TODO: need way to combine channels from multiple textures into one
	#  before the encode.

	# can mix formats for a given platform
	# can also set a specific encoder here, these are the presets
	# -optopaque drops bc7 to bc1, and etc2rgba to etc2rgb on opaques (half size)
	# Note that bc1 and etc2 can't represent 4 unique colors in 4x4 block,
	#  but BC7/Astc can via partitioning.

	fmtAlbedo = ""
	fmtNormal = ""
	fmtSDF = ""
	fmtMetalRoughness = ""
	fmtMask = ""
	fmtHeight = ""

	# note 1/2/2nm in astc need swizzles to store more efficiently
	# and at 4x4 aren't any smaller than explicit values
	# prefer etc since it's smaller and higher bit depth (11-bits)

	# note sdf and signed data will look odd in Preview.  It's not
	# really setup for signed data.  

	# heightScale and wrap is really a per texture setting, but don't have 
	# support for that yet.
	fmtHeightArgs = " -height -heightScale 4 -wrap"

	if platform == "ios":
		# use astc since has more quality settings
		fmtAlbedo = " -f astc4x4 -srgb -premul"
		fmtNormal = " -f etc2rg -signed -normal"
		fmtMetalRoughness = " -f etc2rg"
		fmtMask = " -f etc2r"
		fmtSDF = " -f etc2r -signed -sdf"
		fmtHeight = fmtNormal + fmtHeightArgs

	elif platform == "android":
		fmtAlbedo = " -f etc2rgba -srgb -premul -optopaque" # or astc
		fmtNormal = " -f etc2rg -signed -normal"
		fmtMetalRoughness = " -f etc2rg"
		fmtMask = " -f etc2r"
		fmtSDF = " -f etc2r -signed -sdf"
		fmtHeight = fmtNormal + fmtHeightArgs

	elif platform == "mac":
		# bc1 on Toof has purple, green, yellow artifacts with bc7enc, and has more banding
		# and a lot of weird blocky artifacts, look into bc1 encoder.  
		# Squish BC1 has more blocky artifacts, but not random color artifacts.
		fmtAlbedo = " -f bc7 -srgb -premul" # + " -optopaque"
		fmtNormal = " -f bc5 -signed -normal"
		fmtMetalRoughness = " -f bc5"
		fmtMask = " -f bc4"
		fmtSDF = " -f bc4 -signed -sdf"
		fmtHeight = fmtNormal + fmtHeightArgs

	elif platform == "win":
		# bc1 on Toof has purple, green, yellow artifacts with bc7enc, and has more banding
		# and a lot of weird blocky artifacts, look into bc1 encoder
		fmtAlbedo = " -f bc7 -srgb -premul" # + " -optopaque"
		fmtNormal = " -f bc5 -signed -normal"
		fmtMetalRoughness = " -f bc5"
		fmtMask = " -f bc4"
		fmtSDF = " -f bc4 -signed -sdf"
		fmtHeight = fmtNormal + fmtHeightArgs

	elif platform == "any":
		# output to s/rgba8u, then run through ktxsc to go to BasisLZ
		# no signed formats, but probably can transcode to one
		fmtAlbedo = " -f rgba8 -srgb -premul" # + " -optopaque"
		fmtNormal = " -f rgba8 -swizzle rg01 -normal"
		fmtMetalRoughness = " -f rgba8 -swizzle r001"
		fmtMask = " -f rgba8 -swizzle r001"
		fmtSDF = " -f rgba8 -swizzle r001 -sdf"
		fmtHeight = fmtNormal + fmtHeightArgs

	else:
		return 1

	# set to empty string to skip fmtUnknown
	fmtUnknown = fmtAlbedo

	moreArgs = ""
	
	# default is 49
	moreArgs += " -quality " + str(quality)
	
	# downsample to output this maximum dimension (across all kinds)
	# for example a cube map can be 1024 x (6x1024) and this won't chop the long part of the strip
	moreArgs += " -mipmax 1024"

	if verbose:
		moreArgs += " -v"
		
	formats = [fmtUnknown, fmtAlbedo, fmtNormal, fmtSDF, fmtMetalRoughness, fmtMask, fmtHeight]

	formats = [fmt + moreArgs for fmt in formats]
	
	#------------------------------------------
	# Encoding

	timer = 0.0
	timer -= time.perf_counter()

	result = 0
		
	processor = TextureProcessor(platform, appKram, maxCores, force, script, scriptFile, formats)
	if ktx2:
		processor.doKTX2 = ktx2

		# used to need all of these apps to gen ktx2, but can gen directly from kram now
		# leaving these to test aastc case
		processor.appKtx2 = appKtx2
		processor.appKtx2sc = appKtx2sc
		processor.doUastc = doUastc

		# check app still useful
		processor.appKtx2check = appKtx2check
		
	for srcDir in srcDirs:
		dstDir = dstDirForPlatform + srcDir
		os.makedirs(dstDir, exist_ok = True)
		result = processor.processTexturesKram(srcDirBase + srcDir, dstDir)
		if result != 0:
			break

	if result == 0 and script:
		result = processor.processScriptKram()

	timer += time.perf_counter()
	print("took total {0:.3f}s".format(timer))

	#------------------------------------------
	# Bundling
	
	if bundle:
		# TODO: build an asset catalog symlinked to zip for app slicing and ODR on iOS/macOS, Android has similar
		
		# DONE: need to push/popDir but basically strip the full path before files are zipped.
		#  want find to generate files from within the out/platform directory.
		os.chdir(dstDirForPlatform)

		# either store ktx2 or compress ktx in updating a zip with the data
		if ktx2:
			compressionLevel = 0
			dstBundle = "bundle-" + platform + "-ktx2" + ".zip"
			command = "find {0} -name '*.ktx2' | zip -u -{1} -@ {2}".format(".", compressionLevel, dstBundle)
		else:
			# see https://aras-p.info/blog/2021/08/05/EXR-Zip-compression-levels/ 
			# compression level 4 is 2x faster, and only slightly less compression than default of 6
			compressionLevel = 4
			dstBundle = "bundle-" + platform + "-ktx" + ".zip"
			command = "find {0} -name '*.ktx' | zip -u -{1} -@ {2}".format(".", compressionLevel, dstBundle)

		print("running " + command)

		# find or zip return number of file count, so have to check < 0
		retval = subprocess.call(command, shell=True)
		if retval < 0:
			print("cmd: failed '" + command + "' with value " + str(retval))
			return 1

	return result

if __name__== "__main__":
	processTextures()

