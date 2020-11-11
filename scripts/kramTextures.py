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
		
		elif ("-array1d" in name):
			kind = TextureType.Tex1DArray
		elif ("-array2d" in name):
			kind = TextureType.Tex2DArray
		elif ("-arraycube" in name):
			kind = TextureType.CubeArray
			
		return kind

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
		if not (srcExtension == ".png" or srcExtension == ".ktx"):
			if not srcPath.endswith(".DS_Store"):
				print("skipping unknown extension on file {0}".format(srcPath))
			return 0
		
		srcFilename = os.path.basename(srcRoot) # just the name no ext

		ext = ".ktx"
		dstName = srcFilename + ext
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

		# TODO: handle more texture types (cube, array, etc).  Use naming convention for that.
		# split these up off name + strip textures, can figure out most of atlasing from that and pow2.
		# if it's an altas containing smaller tiles in rows, then may need to supply tile size/count
		# and possibly horizontal vs. vertical atlasing.  Count more general since it applies even after dropping mips.
		# app currently assumes smaller dimension.  Can spawn out to kram info to get width and height.

		texType = self.textureType(srcRoot)

		switcher = {
			TextureType.Tex2D: " -type 2d",
			TextureType.Tex3D: " -type 3d",
			TextureType.Cube: " -type cube",
			
			TextureType.Tex1DArray: " -type 1darray",
			TextureType.Tex2DArray: " -type 2darray",
			TextureType.CubeArray: " -type cubearray",
		}
		typeText = switcher.get(texType, " -type 2d")

		cmd = "encode" + fmt + typeText + " -i " + srcPath + " -o " + dstFile

		# can print out commands to script and then process that all in C++
		if self.doScript:
			self.scriptFile.write(cmd)
			self.scriptFile.write('\n')
			result = 0

		else:
			timer = -time.perf_counter()
		
			result = self.spawn(self.appKram + " " + cmd)

			# report slow textures
			slowTextureTime = 1 # 1sec
			timer += time.perf_counter()
			if timer > slowTextureTime:
				print("perf: encode {0} took {1:.3f}s".format(dstName, timer))

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
@click.option('-p', '--platform', type=click.Choice(['ios', 'mac', 'win', 'android']), required=True, help="build platform")
@click.option('-c', '--container', type=click.Choice(['ktx', 'ktxa']), default="ktx", help="container type")
@click.option('-v', '--verbose', is_flag=True, help="verbose output")
@click.option('-q', '--quality', default=49, type=click.IntRange(0, 100), help="quality affects encode speed")
@click.option('-j', '--jobs', default=64, help="max physical cores to use")
@click.option('--force', is_flag=True, help="force rebuild ignoring modstamps")
@click.option('--script', is_flag=True, help="generate kram script and execute that")
def processTextures(platform, container, verbose, quality, jobs, force, script):
	# output to multiple dirs by type

	# eventually pass these in as strings, so script is generic
	appKram = "../build/Release/kram"

	srcDirBase = "../tests/src/"

	dstDirBase = "../tests/out/"
	dstDirForPlatform = dstDirBase + platform + "/"
	
	scriptFile = dstDirForPlatform + "kramscript.txt"
	

	# can process multiple src folders, and skip some
	srcDirs = [""]

	maxCores = jobs

	#------------------------------------------
	# TODO: allow multiple platforms to be built in one call

	# TODO: need a script per file with more info than just the filename
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
	
	# note 1/2/2nm in astc need swizzles to store more efficiently
	# and at 4x4 aren't any smaller than explicit values
	# prefer etc since it's smaller and higher bit depth (11-bits)

	# note sdf and signed data will look odd in Preview.  It's not
	# really setup for signed data.
	
	if platform == "ios":
		# use astc since has more quality settings
		fmtAlbedo = " -f astc4x4 -srgb -premul"
		fmtNormal = " -f etc2rg -signed -normal"
		fmtMetalRoughness = " -f etc2rg"
		fmtMask = " -f etc2r"
		fmtSDF = " -f etc2r -signed -sdf"

	elif platform == "android":
		fmtAlbedo = " -f etc2rgba -srgb -premul -optopaque" # or astc
		fmtNormal = " -f etc2rg -signed -normal"
		fmtMetalRoughness = " -f etc2rg"
		fmtMask = " -f etc2r"
		fmtSDF = " -f etc2r -signed -sdf"
		
	elif platform == "mac":
		fmtAlbedo = " -f bc7 -srgb -premul -optopaque"
		fmtNormal = " -f bc5 -signed -normal"
		fmtMetalRoughness = " -f bc5"
		fmtMask = " -f bc4"
		fmtSDF = " -f bc4 -signed -sdf"
		
	elif platform == "win":
		fmtAlbedo = " -f bc7 -srgb -premul -optopaque"
		fmtNormal = " -f bc5 -signed -normal"
		fmtMetalRoughness = " -f bc5"
		fmtMask = " -f bc4"
		fmtSDF = " -f bc4 -signed -sdf"

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
		
	formats = [fmtUnknown, fmtAlbedo, fmtNormal, fmtSDF, fmtMetalRoughness, fmtMask]

	formats = [fmt + moreArgs for fmt in formats]
	
	#------------------------------------------

	timer = 0.0
	timer -= time.perf_counter()

	result = 0
		
	processor = TextureProcessor(platform, appKram, maxCores, force, script, scriptFile, formats)

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

	return result

if __name__== "__main__":
	processTextures()

