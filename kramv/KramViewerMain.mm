// kram - Copyright 2020 by Alec Miller. - MIT License
// The license and copyright notice shall be included
// in all copies or substantial portions of the Software.

// using -fmodules and -fcxx-modules
@import Cocoa;
@import Metal;
@import MetalKit;

//#import <Cocoa/Cocoa.h>
//#import <Metal/Metal.h>
//#import <MetalKit/MetalKit.h>
//#import <TargetConditionals.h>

#import "KramRenderer.h"
#import "KramShaders.h"

// C++
#include "KramLib.h"
#include "KramVersion.h"  // keep kramv version in sync with libkram

//#include "KramMipper.h"

//#include "Kram.h"
//#include "KramFileHelper.h"
//#include "KramMmapHelper.h"
//#include "KramZipHelper.h"

//#include "KramImage.h"
#include "KramViewerBase.h"



#ifdef NDEBUG
static bool doPrintPanZoom = false;
#else
static bool doPrintPanZoom = true;
#endif

using namespace simd;
using namespace kram;
using namespace NAMESPACE_STL;


// this aliases the existing string, so can't chop extension
inline const char* toFilenameShort(const char* filename) {
    const char* filenameShort = strrchr(filename, '/');
    if (filenameShort == nullptr) {
        filenameShort = filename;
    }
    else {
        filenameShort += 1;
    }
    return filenameShort;
}

//-------------

// This is so annoying, but otherwise the hud always intercepts clicks intended
// for the underlying TableView.
// https://stackoverflow.com/questions/15891098/nstextfield-click-through
@interface MyNSTextField : NSTextField

@end

@implementation MyNSTextField
{
    
}

// override to allow clickthrough
- (NSView*)hitTest:(NSPoint)aPoint
{
    return nil;
}

@end

//-------------

@interface MyMTKView : MTKView
// for now only have a single imageURL
@property(retain, nonatomic, readwrite, nullable) NSURL *imageURL;

//@property (nonatomic, readwrite, nullable) NSPanGestureRecognizer* panGesture;
@property(retain, nonatomic, readwrite, nullable)
    NSMagnificationGestureRecognizer *zoomGesture;

@property(nonatomic, readwrite) double lastArchiveTimestamp;

// can hide hud while list view is up
@property(nonatomic, readwrite) bool hudHidden;

- (BOOL)loadTextureFromURL:(NSURL *)url;

- (void)setHudText:(const char *)text;

- (void)tableViewSelectionDidChange:(NSNotification *)notification;

- (void)addNotifications;

- (void)removeNotifications;

- (void)fixupDocumentList;

@end

//-------------

// https://medium.com/@kevingutowski/how-to-setup-a-tableview-in-2019-obj-c-c7dece203333
@interface TableViewController : NSObject <NSTableViewDataSource, NSTableViewDelegate>
@property (nonatomic, strong) NSMutableArray<NSString*>* items;
@end

@implementation TableViewController

- (instancetype)init {
    self = [super init];
    
    _items = [[NSMutableArray alloc] init];
    return self;
}

// NSTableViewDataSource
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return self.items.count;
}

// NSTableViewDelegate
-(NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    NSString *identifier = tableColumn.identifier;
    NSTableCellView *cell = [tableView makeViewWithIdentifier:identifier owner:self];
    cell.textField.stringValue = [self.items objectAtIndex:row];
    return cell;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
   // does not need to respond, have a listener on this notification
}
@end

//-------------

@interface KramDocument : NSDocument

@end

@interface KramDocument ()

@end

@implementation KramDocument

- (instancetype)init
{
    self = [super init];
    if (self) {
        // Add your subclass-specific initialization here.
    }
    return self;
}

+ (BOOL)autosavesInPlace
{
    return NO;  // YES;
}

// call when "new" called
- (void)makeWindowControllers
{
    // Override to return the Storyboard file name of the document.
    // NSStoryboard* storyboard = [NSStoryboard storyboardWithName:@"Main"
    // bundle:nil]; NSWindowController* controller = [storyboard
    // instantiateControllerWithIdentifier:@"NameNeeded]; [self
    //addWindowController:controller];
}

- (NSData *)dataOfType:(nonnull NSString *)typeName
                 error:(NSError *_Nullable __autoreleasing *)outError
{
    // Insert code here to write your document to data of the specified type. If
    // outError != NULL, ensure that you create and set an appropriate error if
    // you return nil. Alternatively, you could remove this method and override
    // -fileWrapperOfType:error:, -writeToURL:ofType:error:, or
    // -writeToURL:ofType:forSaveOperation:originalContentsURL:error: instead.
    [NSException raise:@"UnimplementedMethod"
                format:@"%@ is unimplemented", NSStringFromSelector(_cmd)];
    return nil;
}



- (BOOL)readFromURL:(nonnull NSURL *)url
             ofType:(nonnull NSString *)typeName
              error:(NSError *_Nullable __autoreleasing *)outError
{
    // called from OpenRecent documents menu

#if 0
    //MyMTKView* view = self.windowControllers.firstObject.window.contentView;
    //return [view loadTextureFromURL:url];
#else

    // TODO: This is only getting called on first open on macOS 12.0 even with hack below.
    // find out why.
    
    NSApplication *app = [NSApplication sharedApplication];
    MyMTKView *view = app.mainWindow.contentView;
    BOOL success = [view loadTextureFromURL:url];
    if (success) {
        // Note: if I return NO from this call then a dialog pops up that image
        // couldn't be loaded, but then the readFromURL is called everytime a new
        // image is picked from the list.

        [view setHudText:""];
        [view fixupDocumentList];
    }

    return success;
#endif
}

@end

//-------------

@interface AppDelegate : NSObject <NSApplicationDelegate>

- (IBAction)showAboutDialog:(id)sender;

@end

@interface AppDelegate ()

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Insert code here to initialize your application
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
    // Insert code here to tear down your application
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:
    (NSApplication *)sender
{
    return YES;
}

- (void)application:(NSApplication *)sender
           openURLs:(nonnull NSArray<NSURL *> *)urls
{
    // this is called from "Open In..."
    MyMTKView *view = sender.mainWindow.contentView;

    // TODO: if more than one url dropped, and they are albedo/nmap, then display
    // them together with the single uv set.  Need controls to show one or all
    // together.

    // TODO: also do an overlapping diff if two files are dropped with same
    // dimensions.

    NSURL *url = urls.firstObject;
    [view loadTextureFromURL:url];
    [view fixupDocumentList];
}



- (IBAction)showAboutDialog:(id)sender
{
    // calls openDocumentWithContentsOfURL above
    NSMutableDictionary<NSAboutPanelOptionKey, id> *options =
        [[NSMutableDictionary alloc] init];

    // name and icon are already supplied

    // want to embed the git tag here
    options[@"Copyright"] =
        [NSString stringWithUTF8String:"kram ©2020,2021 by Alec Miller"];

    // add a link to kram website, skip the Visit text
    NSMutableAttributedString *str = [[NSMutableAttributedString alloc]
        initWithString:@"https://github.com/alecazam/kram"];
    [str addAttribute:NSLinkAttributeName
                value:@"https://github.com/alecazam/kram"
                range:NSMakeRange(0, str.length)];

    [str appendAttributedString:
             [[NSAttributedString alloc]
                 initWithString:
                     [NSString
                         stringWithUTF8String:
                             "\n"
                             "kram is open-source and inspired by the\n"
                             "software technologies of these companies\n"
                             "  Khronos, Binomial, ARM, Google, and Apple\n"
                             "and devs who generously shared their work.\n"
                             "  Simon Brown, Rich Geldreich, Pete Harris,\n"
                             "  Philip Rideout, Romain Guy, Colt McAnlis,\n"
                             "  John Ratcliff, Sean Parent, David Ireland,\n"
                             "  Mark Callow, Mike Frysinger, Yann Collett\n"]]];

    options[NSAboutPanelOptionCredits] = str;

    // skip the v character
    const char *version = KRAM_VERSION;
    version += 1;

    // this is the build version, should be github hash?
    options[NSAboutPanelOptionVersion] = @"";

    // this is app version
    options[NSAboutPanelOptionApplicationVersion] =
        [NSString stringWithUTF8String:version];

    [[NSApplication sharedApplication]
        orderFrontStandardAboutPanelWithOptions:options];

    //[[NSApplication sharedApplication] orderFrontStandardAboutPanel:sender];
}

@end

//-------------

enum Key {
    A = 0x00,
    S = 0x01,
    D = 0x02,
    F = 0x03,
    H = 0x04,
    G = 0x05,
    Z = 0x06,
    X = 0x07,
    C = 0x08,
    V = 0x09,
    B = 0x0B,
    Q = 0x0C,
    W = 0x0D,
    E = 0x0E,
    R = 0x0F,
    Y = 0x10,
    T = 0x11,
    O = 0x1F,
    U = 0x20,
    I = 0x22,
    P = 0x23,
    L = 0x25,
    J = 0x26,
    K = 0x28,
    N = 0x2D,
    M = 0x2E,

    // https://eastmanreference.com/complete-list-of-applescript-key-codes
    Num1 = 0x12,
    Num2 = 0x13,
    Num3 = 0x14,
    Num4 = 0x15,
    Num5 = 0x17,
    Num6 = 0x16,
    Num7 = 0x1A,
    Num8 = 0x1C,
    Num9 = 0x19,
    Num0 = 0x1D,

    LeftBrace = 0x21,
    RightBrace = 0x1E,

    LeftBracket = 0x21,
    RightBracket = 0x1E,

    Quote = 0x27,
    Semicolon = 0x29,
    Backslash = 0x2A,
    Comma = 0x2B,
    Slash = 0x2C,

    LeftArrow = 0x7B,
    RightArrow = 0x7C,
    DownArrow = 0x7D,
    UpArrow = 0x7E,
    
    Space = 0x31,
    Escape = 0x35,
};

/*

// This is meant to advance a given image through a variety of encoder formats.
// Then can compare the encoding results and pick the better one.
// This could help artist see the effect on all mips of an encoder choice, and
dial up/down the setting.
// Would this cycle through astc and bc together, or separately.
MyMTLPixelFormat encodeSrcTextureAsFormat(MyMTLPixelFormat currentFormat, bool
increment) {
    // if dev drops a png, then have a mode to see different encoding styles
    // on normals, it would just be BC5, ETCrg, ASTCla and blocks
    #define findIndex(array, x) \
        for (int32_t i = 0, count = sizeof(array); i < count; ++i) { \
            if (array[i] == x) { \
                int32_t index = i; \
                if (increment) \
                    index = (index + 1) % count; \
                else \
                    index = (index + count - 1) % count; \
                newFormat = array[index]; \
                break; \
            } \
        }

    MyMTLPixelFormat newFormat = currentFormat;

    // these are formats to cycle through
    MyMTLPixelFormat bc[]     = { MyMTLPixelFormatBC7_RGBAUnorm,
MyMTLPixelFormatBC3_RGBA, MyMTLPixelFormatBC1_RGBA }; MyMTLPixelFormat bcsrgb[]
= { MyMTLPixelFormatBC7_RGBAUnorm_sRGB, MyMTLPixelFormatBC3_RGBA_sRGB,
MyMTLPixelFormatBC1_RGBA_sRGB };

    // TODO: support non-square block with astcenc
    MyMTLPixelFormat astc[]     = { MyMTLPixelFormatASTC_4x4_LDR,
MyMTLPixelFormatASTC_5x5_LDR, MyMTLPixelFormatASTC_6x6_LDR,
MyMTLPixelFormatASTC_8x8_LDR }; MyMTLPixelFormat astcsrgb[] = {
MyMTLPixelFormatASTC_4x4_sRGB, MyMTLPixelFormatASTC_5x5_sRGB,
MyMTLPixelFormatASTC_6x6_sRGB, MyMTLPixelFormatASTC_8x8_sRGB }; MyMTLPixelFormat
astchdr[]  = { MyMTLPixelFormatASTC_4x4_HDR, MyMTLPixelFormatASTC_5x5_HDR,
MyMTLPixelFormatASTC_6x6_HDR, MyMTLPixelFormatASTC_8x8_HDR };

    if (isASTCFormat(currentFormat)) {
        if (isHDRFormat(currentFormat)) {
            // skip it, need hdr decode for Intel
            // findIndex(astchdr, currentFormat);
        }
        else if (isSrgbFormat(currentFormat)) {
            findIndex(astcsrgb, currentFormat);
        }
        else {
            findIndex(astc, currentFormat);
        }
    }
    else if (isBCFormat(currentFormat)) {
        if (isHDRFormat(currentFormat)) {
            // skip it for now, bc6h
        }
        else if (isSrgbFormat(currentFormat)) {
            findIndex(bcsrgb, currentFormat);
        }
        else {
            findIndex(bc, currentFormat);
        }
    }

    #undef findIndex

    return newFormat;
}

void encodeSrcForEncodeComparisons(bool increment) {
    auto newFormat = encodeSrcTextureAsFormat(displayedFormat, increment);

    // This is really only useful for variable block size formats like ASTC
    // maybe some value in BC7 to BC1 comparison (original vs. BC7 vs. BC1)

     // TODO: have to encode and then decode astc/etc on macOS-Intel
     // load png and keep it around, and then call encode and then diff the
image against the original pixels
     // 565 will always differ from the original.

     // Once encode generated, then cache result, only ever display two textures
     // in a comparison mode. Also have eyedropper sample from second texture
     // could display src vs. encode, or cached textures against each other
     // have PSNR too ?

    // see if the format is in cache

    // encode incremented format and cache, that way don't wait too long
    // and once all encode formats generated, can cycle through them until next
image loaded

    // Could reuse the same buffer for all ASTC formats, larger blocks always
need less mem
    //KramImage image; // TODO: move encode to KTXImage, convert png to one
layer KTXImage
    //image.open(...);
    //image.encode(dstImage);
    //decodeIfNeeded(dstImage, dstImageDecoded);
    //comparisonTexture = [createImage:image];
    //set that onto the shader to diff against after recontruct

    // this format after decode may not be the same
    displayedFormat = newFormat;
}
*/

// also NSPasteboardTypeURL
// also NSPasteboardTypeTIFF
NSArray<NSString *> *pasteboardTypes = @[ NSPasteboardTypeFileURL ];

@implementation MyMTKView {
    NSMenu *_viewMenu;  // really the items
    NSStackView *_buttonStack;
    NSMutableArray<NSButton *> *_buttonArray;
    NSTextField *_hudLabel;
    NSTextField *_hudLabel2;
    
    // Offer list of files in archives
    // TODO: move to NSOutlineView since that can show archive folders with content inside
    IBOutlet NSTableView *_tableView;
    IBOutlet TableViewController *_tableViewController;
    
    IBOutlet NSTableView *_shapesTableView;
    IBOutlet TableViewController *_shapesTableViewController;
   
    vector<string> _textSlots;
    ShowSettings *_showSettings;

    // allow zip files to be dropped and opened, and can advance through bundle
    // content
    ZipHelper _zip;
    MmapHelper _zipMmap;
    int32_t _fileArchiveIndex;
    BOOL _noImageLoaded;

    vector<string> _folderFiles;
    int32_t _fileFolderIndex;
}

- (void)awakeFromNib
{
    [super awakeFromNib];

    // TODO: see if can only open this
    // NSLog(@"AwakeFromNIB");
}

// to get upper left origin like on UIView
#if KRAM_MAC
- (BOOL)isFlipped
{
    return YES;
}
#endif

// Gesture regognizers are so annoying. pan requires click on touchpad
// when I just want to swipe.  Might only use for zoom.  This works
// nothing like Apple Preview, so they must not be using these.
// Also zoom recognizer jumps instead of smooth pan in/out.
// Could mix pinch-zoom with wheel-based pan.
//
// TODO: Sometimes getting panels from right side popping in when trying to pan
// on macOS without using pan gesture.

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];

    _showSettings = new ShowSettings;

    self.clearColor = MTLClearColorMake(0.0f, 0.0f, 0.0f, 0.0f);

    self.clearDepth = _showSettings->isReverseZ ? 0.0f : 1.0f;

    // only re-render when changes are made
    // Note: this breaks ability to gpu capture, since display link not running.
    // so disable this if want to do captures.  Or just move the cursor to capture.
#ifndef NDEBUG  // KRAM_RELEASE
    self.enableSetNeedsDisplay = YES;
#endif
    // openFile in appDelegate handles "Open in..."

    _textSlots.resize(2);
    
    // added for drag-drop support
    [self registerForDraggedTypes:pasteboardTypes];

    _zoomGesture = [[NSMagnificationGestureRecognizer alloc]
        initWithTarget:self
                action:@selector(handleGesture:)];
    [self addGestureRecognizer:_zoomGesture];

    _buttonArray = [[NSMutableArray alloc] init];
    _buttonStack = [self _addButtons];

    // hide until image loaded
    _buttonStack.hidden = YES;
    _noImageLoaded = YES;

    _hudLabel2 = [self _addHud:YES];
    _hudLabel = [self _addHud:NO];
    [self setHudText:""];
    
    return self;
}

- (nonnull ShowSettings *)showSettings
{
    return _showSettings;
}

-(void)fixupDocumentList
{
    // DONE: this recent menu only seems to work the first time
    // and not in subsequent calls to the same entry.  readFromUrl isn't even
    // called. So don't get a chance to switch back to a recent texture. Maybe
    // there's some list of documents created and so it doesn't think the file
    // needs to be reloaded.
   
    // Clear the document list so readFromURL keeps getting called
    // Can't remove currentDoc, so have to skip that
    NSDocumentController *dc = [NSDocumentController sharedDocumentController];
    NSDocument *currentDoc = dc.currentDocument;
    NSMutableArray *docsToRemove = [[NSMutableArray alloc] init];
    for (NSDocument *doc in dc.documents) {
        if (doc != currentDoc)
            [docsToRemove addObject:doc];
    }

    for (NSDocument *doc in docsToRemove) {
        [dc removeDocument:doc];
    }
}

- (NSStackView *)_addButtons
{
    const int32_t numButtons = 31;
    const char *names[numButtons * 2] = {
        " ",
        "Play",
        "?",
        "Help",
        "I",
        "Info",
        "H",
        "Hud",
        "S",
        "Show All",

        "O",
        "Preview",
        "W",
        "Repeat",
        "P",
        "Premul",
        "N",
        "Signed",

        "-",
        "",

        "E",
        "Debug",
        "D",
        "Grid",
        "C",
        "Checker",
        "U",
        "Toggle UI",

        "-",
        "",

        "M",
        "Mip",
        "F",
        "Face",
        "Y",
        "Array",
        "J",
        "Next",
        "L",
        "Reload",
        "0",
        "Fit",

        "-",
        "",

        "8",
        "Shape",
        "6",
        "Shape Channel",
        "5",
        "Lighting",
        "T",
        "Tangents",

        // TODO: need to shift hud over a little
        // "UI", - add to show/hide buttons

        "-",
        "",

        // make these individual toggles and exclusive toggle off shift
        "R",
        "Red",
        "G",
        "Green",
        "B",
        "Blue",
        "A",
        "Alpha",
    };

    NSRect rect = NSMakeRect(0, 10, 30, 30);

    //#define ArrayCount(x) ((x) / sizeof(x[0]))

    NSMutableArray *buttons = [[NSMutableArray alloc] init];

    for (int32_t i = 0; i < numButtons; ++i) {
        const char *icon = names[2 * i + 0];
        const char *tip = names[2 * i + 1];

        NSString *name = [NSString stringWithUTF8String:icon];
        NSString *toolTip = [NSString stringWithUTF8String:tip];

        NSButton *button = nil;

        button = [NSButton buttonWithTitle:name
                                    target:self
                                    action:@selector(handleAction:)];
        [button setToolTip:toolTip];
        button.hidden = NO;

        button.buttonType = NSButtonTypeToggle;
        // NSButtonTypeOnOff

#if 0
        // can use this with border
        // TODO: for some reason this breaks clicking on buttons
        // TODO: eliminate the rounded border
        button.showsBorderOnlyWhileMouseInside = YES;
        button.bordered = YES;
#else
        button.bordered = NO;
#endif
        [button setFrame:rect];

        // stackView seems to disperse the items evenly across the area, so this
        // doesn't work
        if (icon[0] == '-') {
            // rect.origin.y += 11;
            button.enabled = NO;
        }
        else {
            // sKrect.origin.y += 25;

            // keep all buttons, since stackView will remove and pack the stack
            [_buttonArray addObject:button];
        }

        [buttons addObject:button];
    }

    NSStackView *stackView = [NSStackView stackViewWithViews:buttons];
    stackView.orientation = NSUserInterfaceLayoutOrientationVertical;
    stackView.detachesHiddenViews =
        YES;  // default, but why have to have _buttonArrary
    [self addSubview:stackView];

    // Want menus, so user can define their own shortcuts to commands
    // Also need to enable/disable this via validateUserInterfaceItem
    NSApplication *app = [NSApplication sharedApplication];

    NSMenu *mainMenu = app.mainMenu;
    NSMenuItem *viewMenuItem = mainMenu.itemArray[2];
    _viewMenu = viewMenuItem.submenu;

    // TODO: add a view menu in the storyboard
    // NSMenu* menu = app.windowsMenu;
    //[menu addItem:[NSMenuItem separatorItem]];

    for (int32_t i = 0; i < numButtons; ++i) {
        const char *icon = names[2 * i + 0];  // single char
        const char *title = names[2 * i + 1];

        NSString *toolTip = [NSString stringWithUTF8String:icon];
        NSString *name = [NSString stringWithUTF8String:title];
        NSString *shortcut = @"";  // for now, or AppKit turns key int cmd+shift+key

        if (icon[0] == '-') {
            [_viewMenu addItem:[NSMenuItem separatorItem]];
        }
        else {
            NSMenuItem *menuItem =
                [[NSMenuItem alloc] initWithTitle:name
                                           action:@selector(handleAction:)
                                    keyEquivalent:shortcut];
            menuItem.toolTip = toolTip;  // use in findMenuItem

            // TODO: menus and buttons should reflect any toggle state
            // menuItem.state = Mixed/Off/On;

            [_viewMenu addItem:menuItem];
        }
    }

    [_viewMenu addItem:[NSMenuItem separatorItem]];

    return stackView;
}

- (NSTextField *)_addHud:(BOOL)isShadow
{
    // TODO: This text field is clamping to the height, so have it set to 1200.
    // really want field to expand to fill the window height for large output
    uint32_t w = 800;
    uint32_t h = 1220;
    
    // add a label for the hud
    NSTextField *label = [[MyNSTextField alloc]
        initWithFrame:NSMakeRect(isShadow ? 21 : 20, isShadow ? 21 : 20, w,
                                 h)];
    
    label.preferredMaxLayoutWidth = w;

    label.drawsBackground = NO;
    label.textColor = !isShadow
                          ? [NSColor colorWithSRGBRed:0 green:1 blue:0 alpha:1]
                          : [NSColor colorWithSRGBRed:0 green:0 blue:0 alpha:1];
    label.bezeled = NO;
    label.editable = NO;
    label.selectable = NO;
    label.lineBreakMode = NSLineBreakByClipping;
    label.maximumNumberOfLines = 0;  // fill to height

    // important or interferes with table view
    label.refusesFirstResponder = YES;
    label.enabled = NO;
    
    label.cell.scrollable = NO;
    label.cell.wraps = NO;

    label.hidden = !_showSettings->isHudShown;
    // label.font = NSFont.systemFont(ofSize: NSFont.systemFontSize(for:
    // label.controlSize))

    // UILabel has shadowColor/shadowOffset but NSTextField doesn't

    [self addSubview:label];

    // add vertical constrains to have it fill window, but keep 800 width
    // this didn't seem to work, can do in Storyboard
    // NSDictionary* views = @{ @"label" : label };
    //[self addConstraints:[NSLayoutConstraint
    //constraintsWithVisualFormat:@"H:|-[label]" options:0 metrics:nil
    //views:views]]; [self addConstraints:[NSLayoutConstraint
    //constraintsWithVisualFormat:@"V:|-[label]" options:0 metrics:nil
    //views:views]];

    return label;
}

- (void)doZoomMath:(float)newZoom newPan:(float2 &)newPan
{
    // transform the cursor to texture coordinate, or clamped version if outside
    Renderer *renderer = (Renderer *)self.delegate;
    float4x4 projectionViewModelMatrix =
        [renderer computeImageTransform:_showSettings->panX
                                   panY:_showSettings->panY
                                   zoom:_showSettings->zoom];

    // convert from pixel to clip space
    float halfX = _showSettings->viewSizeX * 0.5f;
    float halfY = _showSettings->viewSizeY * 0.5f;
    
    // sometimes get viewSizeX that's scaled by retina, and other times not.
    // account for contentScaleFactor (viewSizeX is 2x bigger than cursorX on
    // retina display) now passing down drawableSize instead of view.bounds.size
    halfX /= (float)_showSettings->viewContentScaleFactor;
    halfY /= (float)_showSettings->viewContentScaleFactor;
    
    float4x4 viewportMatrix =
    {
        (float4){ halfX,      0, 0, 0 },
        (float4){ 0,     -halfY, 0, 0 },
        (float4){ 0,          0, 1, 0 },
        (float4){ halfX,  halfY, 0, 1 },
    };
    viewportMatrix = inverse(viewportMatrix);
    
    float4 cursor = float4m(_showSettings->cursorX, _showSettings->cursorY, 0.0f, 1.0f);
    
    cursor = viewportMatrix * cursor;
    
    //NSPoint clipPoint;
    //clipPoint.x = (point.x - halfX) / halfX;
    //clipPoint.y = -(point.y - halfY) / halfY;

    // convert point in window to point in model space
    float4x4 mInv = inverse(projectionViewModelMatrix);
    
    float4 pixel = mInv * float4m(cursor.x, cursor.y, 1.0f, 1.0f);
    pixel.xyz /= pixel.w; // in case perspective used

    // allow pan to extend to show all
    float ar = _showSettings->imageAspectRatio();
    float maxX = 0.5f * ar;
    float minY = -0.5f;
    if (_showSettings->isShowingAllLevelsAndMips) {
        maxX += ar * 1.0f * (_showSettings->totalChunks() - 1);
        minY -= 1.0f * (_showSettings->mipCount - 1);
    }

    // X bound may need adjusted for ar ?
    // that's in model space (+/0.5f, +/0.5f), so convert to texture space
    pixel.x = NAMESPACE_STL::clamp(pixel.x, -0.5f * ar, maxX);
    pixel.y = NAMESPACE_STL::clamp(pixel.y, minY, 0.5f);

    // now that's the point that we want to zoom towards
    // No checks on this zoom
    // old - newPosition from the zoom

#if USE_PERSPECTIVE
    // TODO: this doesn't work for perspective
    newPan.x = _showSettings->panX - (_showSettings->zoom - newZoom) *
                                         _showSettings->imageBoundsX * pixel.x;
    newPan.y = _showSettings->panY + (_showSettings->zoom - newZoom) *
                                         _showSettings->imageBoundsY * pixel.y;
#else
    newPan.x = _showSettings->panX - (_showSettings->zoom - newZoom) *
                                         _showSettings->imageBoundsX * pixel.x;
    newPan.y = _showSettings->panY + (_showSettings->zoom - newZoom) *
                                         _showSettings->imageBoundsY * pixel.y;
#endif
}

- (void)handleGesture:(NSGestureRecognizer *)gestureRecognizer
{
    // https://cocoaosxrevisited.wordpress.com/2018/01/06/chapter-18-mouse-events/
    if (gestureRecognizer != _zoomGesture) {
        return;
    }

    bool isFirstGesture = _zoomGesture.state == NSGestureRecognizerStateBegan;

    // TODO: move into object
    static float _originalZoom = 1.0f;
    static float _validMagnification = 1.0f;

    float zoom = _zoomGesture.magnification;
    if (isFirstGesture) {
        _zoomGesture.magnification = 1.0f;
        zoom = _showSettings->zoom;
    }
    else if (zoom * _originalZoom < 0.1f) {
        // can go negative otherwise
        zoom = 0.1f / _originalZoom;
        _zoomGesture.magnification = zoom;
    }
    
    //-------------------------------------

    // https://developer.apple.com/documentation/uikit/touches_presses_and_gestures/handling_uikit_gestures/handling_pinch_gestures?language=objc
    // need to sync up the zoom when action begins or zoom will jump
    if (isFirstGesture) {
        _validMagnification = 1.0f;
        _originalZoom = zoom;
    }
    else {
        // try expontental (this causes a jump, comparison avoids an initial jump
        // zoom = powf(zoom, 1.05f);

        // doing multiply instead of equals here, also does exponential zom
        zoom *= _originalZoom;
    }

    // https://stackoverflow.com/questions/30002361/image-zoom-centered-on-mouse-position

    // DONE: rect is now ar:1 for rect case, so these x values need to be half ar
    // and that's only if it's not rotated.  box/cube/ellipse make also not correspond
    float ar = _showSettings->imageAspectRatio();
    
    // find the cursor location with respect to the image
    float4 bottomLeftCorner = float4m(-0.5 * ar, -0.5f, 0.0f, 1.0f);
    float4 topRightCorner = float4m(0.5 * ar, 0.5f, 0.0f, 1.0f);

    Renderer *renderer = (Renderer *)self.delegate;
    float4x4 newMatrix = [renderer computeImageTransform:_showSettings->panX
                                                    panY:_showSettings->panY
                                                    zoom:zoom];

    // don't allow panning the entire image off the view boundary
    // transform the upper left and bottom right corner of the image
    float4 pt0 = newMatrix * bottomLeftCorner;
    float4 pt1 = newMatrix * topRightCorner;

    // for perspective
    pt0 /= pt0.w;
    pt1 /= pt1.w;

    // see that rectangle intersects the view, view is -1 to 1
    // this handles inversion
    float2 ptOrigin = simd::min(pt0.xy, pt1.xy);
    float2 ptSize = abs(pt0.xy - pt1.xy);

    CGRect imageRect = CGRectMake(ptOrigin.x, ptOrigin.y, ptSize.x, ptSize.y);
    CGRect viewRect = CGRectMake(-1.0f, -1.0f, 2.0f, 2.0f);

    int32_t numTexturesX = _showSettings->totalChunks();
    int32_t numTexturesY = _showSettings->mipCount;

    if (_showSettings->isShowingAllLevelsAndMips) {
        imageRect.origin.y -= (numTexturesY - 1) * imageRect.size.height;

        imageRect.size.width *= numTexturesX;
        imageRect.size.height *= numTexturesY;
    }

    float visibleWidth = imageRect.size.width * _showSettings->viewSizeX /
                         _showSettings->viewContentScaleFactor;
    float visibleHeight = imageRect.size.height * _showSettings->viewSizeY /
                          _showSettings->viewContentScaleFactor;

    // don't allow image to get too big
    // take into account zoomFit, or need to limit zoomFit and have smaller images
    // be smaller on screen
    float maxZoom = std::max(128.0f, _showSettings->zoomFit);
    //float minZoom = std::min(1.0f/8.0f, _showSettings->zoomFit);

    // TODO: 3d models have imageBoundsY of 1, so the limits are hit immediately
    
    int32_t gap = _showSettings->showAllPixelGap;
    
    // Note this includes chunks and mips even if those are not shown
    // so image could be not visible.
    float2 maxZoomXY;
    maxZoomXY.x = maxZoom * (_showSettings->imageBoundsX + gap) * numTexturesX;
    maxZoomXY.y = maxZoom * (_showSettings->imageBoundsY + gap) * numTexturesY;
    
    float minPixelSize = 4;
    float2 minZoomXY;
    minZoomXY.x = minPixelSize; // minZoom * (_showSettings->imageBoundsX + gap) * numTexturesX;
    minZoomXY.y = minPixelSize; // minZoom * (_showSettings->imageBoundsY + gap) * numTexturesY;
   
    // don't allow image to get too big
    bool isZoomChanged = true;
    
    if (visibleWidth > maxZoomXY.x || visibleHeight > maxZoomXY.y) {
        isZoomChanged = false;
    }

    // or too small
    if (visibleWidth < minZoomXY.x || visibleHeight < minZoomXY.y) {
        isZoomChanged = false;
    }

    // or completely off-screen
    if (!NSIntersectsRect(imageRect, viewRect)) {
        isZoomChanged = false;
    }
    
    if (!isZoomChanged) {
        _zoomGesture.magnification = _validMagnification;
        return;
    }

    if (_showSettings->zoom != zoom) {
        // DONE: zoom also changes the pan to zoom about the cursor, otherwise zoom
        // feels wrong. now adjust the pan so that cursor text stays locked under
        // (zoom to cursor)
        float2 newPan;
        [self doZoomMath:zoom newPan:newPan];

        // store this
        _validMagnification = _zoomGesture.magnification;

        _showSettings->zoom = zoom;

        _showSettings->panX = newPan.x;
        _showSettings->panY = newPan.y;

        if (doPrintPanZoom) {
            string text;
            sprintf(text,
                    "Pan %.3f,%.3f\n"
                    "Zoom %.2fx\n",
                    _showSettings->panX, _showSettings->panY, _showSettings->zoom);
            [self setHudText:text.c_str()];
        }

        [self updateEyedropper];
        self.needsDisplay = YES;
    }
}

- (void)mouseMoved:(NSEvent *)event
{
    // pixel in non-square window coords, run thorugh inverse to get texel space
    // I think magnofication of zoom gesture is affecting coordinates reported by
    // this

    NSPoint point = [self convertPoint:[event locationInWindow] fromView:nil];

    // this needs to change if view is resized, but will likely receive mouseMoved
    // events
    _showSettings->cursorX = (int32_t)point.x;
    _showSettings->cursorY = (int32_t)point.y;

    // should really do this in draw call, since moved messeage come in so quickly
    [self updateEyedropper];
}

inline float4 toPremul(const float4 &c)
{
    // premul with a
    float4 cpremul = c;
    float a = c.a;
    cpremul.w = 1.0f;
    cpremul *= a;
    return cpremul;
}

// Writing out to rgba32 for sampling, but unorm formats like ASTC and RGBA8
// are still off and need to use the following.
float  toSnorm8(float c)  { return (255.0f / 127.0f) * c - (128.0f / 127.0f); }
float2 toSnorm8(float2 c) { return (255.0f / 127.0f) * c - (128.0f / 127.0f); }
float3 toSnorm8(float3 c) { return (255.0f / 127.0f) * c - (128.0f / 127.0f); }
float4 toSnorm8(float4 c) { return (255.0f / 127.0f) * c - (128.0f / 127.0f); }

float4 toSnorm(float4 c)  { return 2.0f * c - 1.0f; }

- (void)updateEyedropper
{
    if ((!_showSettings->isHudShown)) {
        return;
    }

    if (_showSettings->imageBoundsX == 0) {
        // TODO: this return will leave old hud text up
        return;
    }

    // don't wait on renderer to update this matrix
    Renderer *renderer = (Renderer *)self.delegate;

    if (_showSettings->isEyedropperFromDrawable()) {
        // this only needs the cursor location, but can't supply uv to
        // displayPixelData

        if (_showSettings->lastCursorX != _showSettings->cursorX ||
            _showSettings->lastCursorY != _showSettings->cursorY) {
            // TODO: this means pan/zoom doesn't update data, may want to track some
            // absolute location in virtal canvas.

            _showSettings->lastCursorX = _showSettings->cursorX;
            _showSettings->lastCursorY = _showSettings->cursorY;

            // This just samples from drawable, so no re-render is needed
            [self showEyedropperData:float2m(0, 0)];

            // TODO: remove this, but only way to get drawSamples to execute right
            // now, but then entire texture re-renders and that's not power efficient.
            // Really just want to sample from the already rendered texture since
            // content isn't animated.

            self.needsDisplay = YES;
        }

        return;
    }

    float4x4 projectionViewModelMatrix =
        [renderer computeImageTransform:_showSettings->panX
                                   panY:_showSettings->panY
                                   zoom:_showSettings->zoom];

    // convert to clip space, or else need to apply additional viewport transform
    float halfX = _showSettings->viewSizeX * 0.5f;
    float halfY = _showSettings->viewSizeY * 0.5f;

    // sometimes get viewSizeX that's scaled by retina, and other times not.
    // account for contentScaleFactor (viewSizeX is 2x bigger than cursorX on
    // retina display) now passing down drawableSize instead of view.bounds.size
    halfX /= (float)_showSettings->viewContentScaleFactor;
    halfY /= (float)_showSettings->viewContentScaleFactor;

    float4 cursor = float4m(_showSettings->cursorX, _showSettings->cursorY, 0.0f, 1.0f);
    
    float4x4 pixelToClipTfm =
    {
        (float4){ halfX,      0, 0, 0 },
        (float4){ 0,     -halfY, 0, 0 },
        (float4){ 0,          0, 1, 0 },
        (float4){ halfX,  halfY, 0, 1 },
    };
    pixelToClipTfm = inverse(pixelToClipTfm);
    
    cursor = pixelToClipTfm * cursor;
    
    //float4 clipPoint;
    //clipPoint.x = (point.x - halfX) / halfX;
    //clipPoint.y = -(point.y - halfY) / halfY;

    // convert point in window to point in texture
    float4x4 mInv = inverse(projectionViewModelMatrix);
    
    float4 pixel = mInv * float4m(cursor.x, cursor.y, 1.0f, 1.0f);
    pixel.xyz /= pixel.w; // in case perspective used

    float ar = _showSettings->imageAspectRatio();
    
    // that's in model space (+/0.5f * ar, +/0.5f), so convert to texture space
    pixel.x = 0.999f * (pixel.x / ar + 0.5f);
    pixel.y = 0.999f * (-pixel.y + 0.5f);

    float2 uv = pixel.xy;

    // pixels are 0 based
    pixel.x *= _showSettings->imageBoundsX;
    pixel.y *= _showSettings->imageBoundsY;

    // TODO: finish this logic, need to account for gaps too, and then isolate to
    // a given level and mip to sample
    //    if (_showSettings->isShowingAllLevelsAndMips) {
    //        pixel.x *= _showSettings->totalChunks();
    //        pixel.y *= _showSettings->mipCount;
    //    }

    // TODO: clearing out the last px visited makes it hard to gather data
    // put value on clipboard, or allow click to lock the displayed pixel and
    // value. Might just change header to px(last): ...
    string text;

    // only display pixel if over image
    if (pixel.x < 0.0f || pixel.x >= (float)_showSettings->imageBoundsX) {
        sprintf(text, "canvas: %d %d\n", (int32_t)pixel.x, (int32_t)pixel.y);
        [self setEyedropperText:text.c_str()];  // ick
        return;
    }
    if (pixel.y < 0.0f || pixel.y >= (float)_showSettings->imageBoundsY) {
        // was blanking out, but was going blank on color_grid-a when over zoomed in
        // image maybe not enough precision with float.
        sprintf(text, "canvas: %d %d\n", (int32_t)pixel.x, (int32_t)pixel.y);
        [self setEyedropperText:text.c_str()];
        return;
    }

    // Note: fromView: nil returns isFlipped coordinate, fromView:self flips it
    // back.

    int32_t newX = (int32_t)pixel.x;
    int32_t newY = (int32_t)pixel.y;

    if (_showSettings->textureLookupX != newX ||
        _showSettings->textureLookupY != newY) {
        // Note: this only samples from the original texture via compute shaders
        // so preview mode pixel colors are not conveyed.  But can see underlying
        // data driving preview.

        // %.0f rounds the value, but want truncation
        _showSettings->textureLookupX = newX;
        _showSettings->textureLookupY = newY;

        [self showEyedropperData:uv];

        // TODO: remove this, but only way to get drawSamples to execute right now,
        // but then entire texture re-renders and that's not power efficient.
        self.needsDisplay = YES;
    }
}

- (void)showEyedropperData:(float2)uv
{
    string text;
    string tmp;

    float4 c = _showSettings->textureResult;

    // DONE: use these to format the text
    MyMTLPixelFormat format = _showSettings->originalFormat;
    bool isSrgb = isSrgbFormat(format);
    bool isSigned = isSignedFormat(format);

    bool isHdr = isHdrFormat(format);
    bool isFloat = isHdr;

    int32_t numChannels = _showSettings->numChannels;

    bool isNormal = _showSettings->isNormal;
    bool isColor = !isNormal;

    bool isDirection = false;
    bool isValue = false;

    if (_showSettings->isEyedropperFromDrawable()) {
        // TODO: could write barycentric, then lookup uv from that
        // then could show the block info.

        // interpret based on shapeChannel, debugMode, etc
        switch (_showSettings->shapeChannel) {
            case ShapeChannelDepth:
                isSigned = false;  // using fract on uv

                isValue = true;
                isFloat = true;
                numChannels = 1;
                break;
            case ShapeChannelUV0:
                isSigned = false;  // using fract on uv

                isValue = true;
                isFloat = true;
                numChannels = 2;  // TODO: fix for 3d uvw
                break;

            case ShapeChannelFaceNormal:
            case ShapeChannelNormal:
            case ShapeChannelTangent:
            case ShapeChannelBitangent:
                isDirection = true;
                numChannels = 3;

                // convert unorm to snnorm
                c = toSnorm(c);
                break;

            case ShapeChannelMipLevel:
                isValue = true;
                isSigned = false;
                isFloat = true;

                // viz is mipNumber as alpha
                numChannels = 1;
                c.r = 4.0 - (c.a * 4.0);
                break;

            default:
                break;
        }

        // debug mode

        // preview vs. not
    }
    else {
        // this will be out of sync with gpu eval, so may want to only display px
        // from returned lookup this will always be a linear color

        int32_t x = _showSettings->textureResultX;
        int32_t y = _showSettings->textureResultY;

        // show uv, so can relate to gpu coordinates stored in geometry and find
        // atlas areas
        append_sprintf(text, "uv:%0.3f %0.3f\n",
                       (float)x / _showSettings->imageBoundsX,
                       (float)y / _showSettings->imageBoundsY);

        // pixel at top-level mip
        append_sprintf(text, "px:%d %d\n", x, y);

        // show block num
        int mipLOD = _showSettings->mipNumber;

        int mipX = _showSettings->imageBoundsX;
        int mipY = _showSettings->imageBoundsY;

        mipX = mipX >> mipLOD;
        mipY = mipY >> mipLOD;

        mipX = std::max(1, mipX);
        mipY = std::max(1, mipY);

        mipX = (int32_t)(uv.x * mipX);
        mipY = (int32_t)(uv.y * mipY);

        _showSettings->textureLookupMipX = mipX;
        _showSettings->textureLookupMipY = mipY;

        // TODO: may want to return mip in pixel readback
        // don't have it right now, so don't display if preview is enabled
        if (_showSettings->isPreview)
            mipLOD = 0;

        auto blockDims = blockDimsOfFormat(format);
        if (blockDims.x > 1)
            append_sprintf(text, "bpx: %d %d\n", mipX / blockDims.x,
                           mipY / blockDims.y);

        // TODO: on astc if we have original blocks can run analysis from
        // astc-encoder about each block.

        // show the mip pixel (only if not preview and mip changed)
        if (mipLOD > 0 && !_showSettings->isPreview)
            append_sprintf(text, "mpx: %d %d\n", mipX, mipY);

        // TODO: more criteria here, can have 2 channel PBR metal-roughness
        // also have 4 channel normals where zw store other data.

        bool isDecodeSigned = isSignedFormat(_showSettings->decodedFormat);
        if (isSigned && !isDecodeSigned) {
            c = toSnorm8(c);
        }
    }

    if (isValue) {
        printChannels(tmp, "val: ", c, numChannels, isFloat, isSigned);
        text += tmp;
    }
    else if (isDirection) {
        // print direction
        isFloat = true;
        isSigned = true;

        printChannels(tmp, "dir: ", c, numChannels, isFloat, isSigned);
        text += tmp;
    }
    else if (isNormal) {
        float nx = c.x;
        float ny = c.y;

        // unorm -> snorm
        if (!isSigned) {
            nx = toSnorm8(nx);
            ny = toSnorm8(ny);
        }

        // Note: not clamping nx,ny to < 1 like in shader

        // this is always postive on tan-space normals
        // assuming we're not viewing world normals
        const float maxLen2 = 0.999 * 0.999;
        float len2 = nx * nx + ny * ny;
        if (len2 > maxLen2)
            len2 = maxLen2;

        float nz = sqrt(1.0f - len2);

        // print the underlying color (some nmaps are xy in 4 channels)
        printChannels(tmp, "lin: ", c, numChannels, isFloat, isSigned);
        text += tmp;

        // print direction
        float4 d = float4m(nx, ny, nz, 0.0f);
        isFloat = true;
        isSigned = true;
        printChannels(tmp, "dir: ", d, 3, isFloat, isSigned);
        text += tmp;
    }
    else if (isColor) {
        // DONE: write some print helpers based on float4 and length
        printChannels(tmp, "lin: ", c, numChannels, isFloat, isSigned);
        text += tmp;

        if (isSrgb) {
            // this saturates the value, so don't use for extended srgb
            float4 s = linearToSRGB(c);

            printChannels(tmp, "srg: ", s, numChannels, isFloat, isSigned);
            text += tmp;
        }

        // display the premul values too, but not fully transparent pixels
        if (c.a > 0.0 && c.a < 1.0f) {
            printChannels(tmp, "lnp: ", toPremul(c), numChannels, isFloat, isSigned);
            text += tmp;

            // TODO: do we need the premul srgb color too?
            if (isSrgb) {
                // this saturates the value, so don't use for extended srgb
                float4 s = linearToSRGB(c);

                printChannels(tmp, "srp: ", toPremul(s), numChannels, isFloat,
                              isSigned);
                text += tmp;
            }
        }
    }

    [self setEyedropperText:text.c_str()];

    // TODO: range display of pixels is useful, only showing pixels that fall
    // within a given range, but would need slider then, and determine range of
    // pixels.
    // TODO: Auto-range is also useful for depth (ignore far plane of 0 or 1).

    // TOOD: display histogram from compute, bin into buffer counts of pixels

    // DONE: stop clobbering hud text, need another set of labels
    // and a zoom preview of the pixels under the cursor.
    // Otherwise, can't really see the underlying color.

    // TODO: Stuff these on clipboard with a click, or use cmd+C?
}

- (void)setEyedropperText:(const char *)text
{
    _textSlots[0] = text;

    [self updateHudText];
}

- (void)setHudText:(const char *)text
{
    _textSlots[1] = text;

    [self updateHudText];
}

- (void)updateHudText
{
    // combine textSlots
    string text = _textSlots[0] + _textSlots[1];

    NSString *textNS = [NSString stringWithUTF8String:text.c_str()];
    _hudLabel2.stringValue = textNS;
    _hudLabel2.needsDisplay = YES;
    
    _hudLabel.stringValue = textNS;
    _hudLabel.needsDisplay = YES;
}

- (void)scrollWheel:(NSEvent *)event
{
    double wheelX = [event scrollingDeltaX];
    double wheelY = [event scrollingDeltaY];

    //    if ([event hasPreciseScrollingDeltas])
    //    {
    //        //wheelX *= 0.01;
    //        //wheelY *= 0.01;
    //    }
    //    else {
    //        //wheelX *= 0.1;
    //        //wheelY *= 0.1;
    //    }

    //---------------------------------------

    // pan
    wheelY = -wheelY;
    wheelX = -wheelX;

    float panX = _showSettings->panX + wheelX;
    float panY = _showSettings->panY + wheelY;

    Renderer *renderer = (Renderer *)self.delegate;
    float4x4 projectionViewModelMatrix =
        [renderer computeImageTransform:panX
                                   panY:panY
                                   zoom:_showSettings->zoom];

    // don't allow panning the entire image off the view boundary
    // transform the upper left and bottom right corner or the image

    // what if zoom moves it outside?
    float ar = _showSettings->imageAspectRatio();
    
    float4 pt0 = projectionViewModelMatrix * float4m(-0.5 * ar, -0.5f, 0.0f, 1.0f);
    float4 pt1 = projectionViewModelMatrix * float4m(0.5 * ar, 0.5f, 0.0f, 1.0f);

    // for perspective
    pt0.xyz /= pt0.w;
    pt1.xyz /= pt1.w;

    float2 ptOrigin = simd::min(pt0.xy, pt1.xy);
    float2 ptSize = abs(pt0.xy - pt1.xy);

    // see that rectangle intersects the view, view is -1 to 1
    CGRect imageRect = CGRectMake(ptOrigin.x, ptOrigin.y, ptSize.x, ptSize.y);
    CGRect viewRect = CGRectMake(-1.0f, -1.0f, 2.0f, 2.0f);

    int32_t numTexturesX = _showSettings->totalChunks();
    int32_t numTexturesY = _showSettings->mipCount;

    if (_showSettings->isShowingAllLevelsAndMips) {
        imageRect.origin.y -= (numTexturesY - 1) * imageRect.size.height;

        imageRect.size.width *= numTexturesX;
        imageRect.size.height *= numTexturesY;
    }

    if (!NSIntersectsRect(imageRect, viewRect)) {
        return;
    }

    if (_showSettings->panX != panX || _showSettings->panY != panY) {
        _showSettings->panX = panX;
        _showSettings->panY = panY;

        if (doPrintPanZoom) {
            string text;
            sprintf(text,
                    "Pan %.3f,%.3f\n"
                    "Zoom %.2fx\n",
                    _showSettings->panX, _showSettings->panY, _showSettings->zoom);
            [self setHudText:text.c_str()];
        }

        [self updateEyedropper];
        self.needsDisplay = YES;
    }
}

- (NSButton *)findButton:(const char *)name
{
    NSString *title = [NSString stringWithUTF8String:name];
    for (NSButton *button in _buttonArray) {
        if (button.title == title)
            return button;
    }
    return nil;
}

- (NSMenuItem *)findMenuItem:(const char *)name
{
    NSString *title = [NSString stringWithUTF8String:name];

    for (NSMenuItem *menuItem in _viewMenu.itemArray) {
        if (menuItem.toolTip == title)
            return menuItem;
    }
    return nil;
}

// use this to enable/disable menus, buttons, etc.  Called on every event
// when not implemented, then user items are always enabled
- (BOOL)validateUserInterfaceItem:(id<NSValidatedUserInterfaceItem>)item
{
    // TODO: tie to menus and buttons states for enable/disable toggles
    // https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/MenuList/Articles/EnablingMenuItems.html

    // MTKView is not doc based, so can't all super
    // return [super validateUserInterfaceItem:anItem];

    return YES;
}

- (void)updateUIAfterLoad
{
    // TODO: move these to actions, and test their state instead of looking up
    // buttons here and in HandleKey.

    // base on showSettings, hide some fo the buttons
    bool isShowAllHidden =
        _showSettings->totalChunks() <= 1 && _showSettings->mipCount <= 1;

    bool isArrayHidden = _showSettings->arrayCount <= 1;
    bool isFaceSliceHidden =
        _showSettings->faceCount <= 1 && _showSettings->sliceCount <= 1;
    bool isMipHidden = _showSettings->mipCount <= 1;

    bool isJumpToNextHidden =
        !(_showSettings->isArchive || _showSettings->isFolder);

    bool isRedHidden = _showSettings->numChannels == 0; // models don't show rgba
    bool isGreenHidden = _showSettings->numChannels <= 1;
    bool isBlueHidden = _showSettings->numChannels <= 2 &&
                        !_showSettings->isNormal;  // reconstruct z = b on normals

    // TODO: also need a hasAlpha for pixels, since many compressed formats like
    // ASTC always have 4 channels but internally store R,RG01,... etc.  Can get
    // more data from swizzle in the props. Often alpha doesn't store anything
    // useful to view.

    // TODO: may want to disable isPremul on block textures that already have
    // premul in data or else premul is applied a second time to the visual

    bool hasAlpha = _showSettings->numChannels >= 3;

    bool isAlphaHidden = !hasAlpha;
    bool isPremulHidden = !hasAlpha;
    bool isCheckerboardHidden = !hasAlpha;

    bool isSignedHidden = !isSignedFormat(_showSettings->originalFormat);
    bool isPlayHidden = !_showSettings->isModel;
    
    // buttons
    [self findButton:" "].hidden = isPlayHidden;
    [self findButton:"Y"].hidden = isArrayHidden;
    [self findButton:"F"].hidden = isFaceSliceHidden;
    [self findButton:"M"].hidden = isMipHidden;
    [self findButton:"S"].hidden = isShowAllHidden;
    [self findButton:"J"].hidden = isJumpToNextHidden;

    [self findButton:"R"].hidden = isRedHidden;
    [self findButton:"G"].hidden = isGreenHidden;
    [self findButton:"B"].hidden = isBlueHidden;
    [self findButton:"A"].hidden = isAlphaHidden;

    [self findButton:"P"].hidden = isPremulHidden;
    [self findButton:"N"].hidden = isSignedHidden;
    [self findButton:"C"].hidden = isCheckerboardHidden;

    // menus (may want to disable, not hide)
    // problem is crashes since menu seems to strip hidden items
    // enabled state has to be handled in validateUserInterfaceItem
    [self findMenuItem:" "].hidden = isPlayHidden;
    [self findMenuItem:"Y"].hidden = isArrayHidden;
    [self findMenuItem:"F"].hidden = isFaceSliceHidden;
    [self findMenuItem:"M"].hidden = isMipHidden;
    [self findMenuItem:"S"].hidden = isShowAllHidden;
    [self findMenuItem:"J"].hidden = isJumpToNextHidden;

    [self findMenuItem:"R"].hidden = isRedHidden;
    [self findMenuItem:"G"].hidden = isGreenHidden;
    [self findMenuItem:"B"].hidden = isBlueHidden;
    [self findMenuItem:"A"].hidden = isAlphaHidden;

    [self findMenuItem:"P"].hidden = isPremulHidden;
    [self findMenuItem:"N"].hidden = isSignedHidden;
    [self findMenuItem:"C"].hidden = isCheckerboardHidden;

    // also need to call after each toggle
    [self updateUIControlState];
}

- (void)updateUIControlState
{
    // there is also mixed
    auto On = NSControlStateValueOn;
    auto Off = NSControlStateValueOff;
#define toState(x) (x) ? On : Off

    Renderer* renderer = (Renderer*)self.delegate;
    auto showAllState = toState(_showSettings->isShowingAllLevelsAndMips);
    auto premulState = toState(_showSettings->isPremul);
    auto signedState = toState(_showSettings->isSigned);
    auto checkerboardState = toState(_showSettings->isCheckerboardShown);
    auto previewState = toState(_showSettings->isPreview);
    auto gridState = toState(_showSettings->isAnyGridShown());
    auto wrapState = toState(_showSettings->isWrap);
    auto debugState = toState(_showSettings->debugMode != DebugModeNone);
    auto playState = toState(_showSettings->isModel && renderer.playAnimations);

    TextureChannels &channels = _showSettings->channels;

    auto redState = toState(channels == TextureChannels::ModeR001);
    auto greenState = toState(channels == TextureChannels::Mode0G01);
    auto blueState = toState(channels == TextureChannels::Mode00B1);
    auto alphaState = toState(channels == TextureChannels::ModeAAA1);

    auto arrayState = toState(_showSettings->arrayNumber > 0);
    auto faceState = toState(_showSettings->faceNumber > 0);
    auto mipState = toState(_showSettings->mipNumber > 0);

    auto meshState = toState(_showSettings->meshNumber > 0);
    auto meshChannelState = toState(_showSettings->shapeChannel > 0);
    auto lightingState =
        toState(_showSettings->lightingMode != LightingModeDiffuse);
    auto tangentState = toState(_showSettings->useTangent);

    // TODO: UI state, and vertical state
    auto uiState = toState(_buttonStack.hidden);

    auto helpState = Off;
    auto infoState = Off;
    auto jumpState = Off;

    // buttons
    [self findButton:" "].state = playState;
    [self findButton:"?"].state = helpState;
    [self findButton:"I"].state = infoState;

    [self findButton:"Y"].state = arrayState;
    [self findButton:"F"].state = faceState;
    [self findButton:"M"].state = mipState;

    [self findButton:"J"].state = jumpState;
    [self findButton:"U"].state = Off;  // always off

    [self findButton:"R"].state = redState;
    [self findButton:"G"].state = greenState;
    [self findButton:"B"].state = blueState;
    [self findButton:"A"].state = alphaState;

    [self findButton:"S"].state = showAllState;
    [self findButton:"O"].state = previewState;
    [self findButton:"8"].state = meshState;
    [self findButton:"6"].state = meshChannelState;
    [self findButton:"5"].state = lightingState;
    [self findButton:"W"].state = wrapState;
    [self findButton:"D"].state = gridState;
    [self findButton:"E"].state = debugState;
    [self findButton:"T"].state = tangentState;

    [self findButton:"P"].state = premulState;
    [self findButton:"N"].state = signedState;
    [self findButton:"C"].state = checkerboardState;

    // menus (may want to disable, not hide)
    // problem is crashes since menu seems to strip hidden items
    // enabled state has to be handled in validateUserInterfaceItem

    // when menu state is selected, it may not uncheck when advancing through
    // state
    [self findMenuItem:" "].state = playState;
    [self findMenuItem:"?"].state = helpState;
    [self findMenuItem:"I"].state = infoState;

    [self findMenuItem:"Y"].state = arrayState;
    [self findMenuItem:"F"].state = faceState;
    [self findMenuItem:"M"].state = mipState;
    [self findMenuItem:"J"].state = jumpState;
    [self findMenuItem:"U"].state = uiState;

    [self findMenuItem:"R"].state = redState;
    [self findMenuItem:"G"].state = greenState;
    [self findMenuItem:"B"].state = blueState;
    [self findMenuItem:"A"].state = alphaState;

    [self findMenuItem:"S"].state = showAllState;
    [self findMenuItem:"O"].state = previewState;
    [self findMenuItem:"8"].state = meshState;
    [self findMenuItem:"6"].state = meshChannelState;
    [self findMenuItem:"5"].state = lightingState;
    [self findMenuItem:"T"].state = tangentState;

    [self findMenuItem:"W"].state = wrapState;
    [self findMenuItem:"D"].state = gridState;
    [self findMenuItem:"E"].state = debugState;

    [self findMenuItem:"P"].state = premulState;
    [self findMenuItem:"N"].state = signedState;
    [self findMenuItem:"C"].state = checkerboardState;
}

// TODO: convert to C++ actions, and then call into Base holding all this
// move pan/zoom logic too.  Then use that as start of Win32 kramv.

- (IBAction)handleAction:(id)sender
{
    NSEvent *theEvent = [NSApp currentEvent];
    bool isShiftKeyDown = (theEvent.modifierFlags & NSEventModifierFlagShift);

    string title;

    // sender is the UI element/NSButton
    if ([sender isKindOfClass:[NSButton class]]) {
        NSButton *button = (NSButton *)sender;
        title = button.title.UTF8String;
    }
    else if ([sender isKindOfClass:[NSMenuItem class]]) {
        NSMenuItem *menuItem = (NSMenuItem *)sender;
        title = menuItem.toolTip.UTF8String;
    }
    else {
        KLOGE("kram", "unknown UI element");
        return;
    }

    int32_t keyCode = -1;

    if (title == "?")
        keyCode = Key::Slash;  // help
    else if (title == "I")
        keyCode = Key::I;
    else if (title == "H")
        keyCode = Key::H;

    else if (title == "S")
        keyCode = Key::S;
    else if (title == "O")
        keyCode = Key::O;
    else if (title == "W")
        keyCode = Key::W;
    else if (title == "P")
        keyCode = Key::P;
    else if (title == "N")
        keyCode = Key::N;

    else if (title == "E")
        keyCode = Key::E;
    else if (title == "D")
        keyCode = Key::D;
    else if (title == "C")
        keyCode = Key::C;
    else if (title == "U")
        keyCode = Key::U;

    else if (title == "M")
        keyCode = Key::M;
    else if (title == "F")
        keyCode = Key::F;
    else if (title == "Y")
        keyCode = Key::Y;
    else if (title == "J")
        keyCode = Key::J;

    // reload/refit
    else if (title == "L")
        keyCode = Key::L;
    else if (title == "0")
        keyCode = Key::Num0;

    // mesh
    else if (title == "8")
        keyCode = Key::Num8;
    else if (title == "6")
        keyCode = Key::Num6;
    else if (title == "5")
        keyCode = Key::Num5;
    else if (title == "T")
        keyCode = Key::T;

    else if (title == "R")
        keyCode = Key::R;
    else if (title == "G")
        keyCode = Key::G;
    else if (title == "B")
        keyCode = Key::B;
    else if (title == "A")
        keyCode = Key::A;

    else if (title == " ")
        keyCode = Key::Space;
    
    if (keyCode >= 0)
        [self handleKey:keyCode isShiftKeyDown:isShiftKeyDown];
}

- (void)keyDown:(NSEvent *)theEvent
{
    bool isShiftKeyDown = theEvent.modifierFlags & NSEventModifierFlagShift;
    uint32_t keyCode = theEvent.keyCode;

    bool isHandled = [self handleKey:keyCode isShiftKeyDown:isShiftKeyDown];
    if (!isHandled) {
        // this will bonk
        [super keyDown:theEvent];
    }
}

- (void)hideTables
{
    _tableView.hidden = YES;
    _shapesTableView.hidden = YES;
}

- (void)updateHudVisibility {
    _hudLabel.hidden = _hudHidden || !_showSettings->isHudShown;
    _hudLabel2.hidden = _hudHidden || !_showSettings->isHudShown;
}

- (bool)handleKey:(uint32_t)keyCode isShiftKeyDown:(bool)isShiftKeyDown
{
    // Some data depends on the texture data (isSigned, isNormal, ..)
    bool isChanged = false;
    bool isStateChanged = false;

    // TODO: fix isChanged to only be set when value changes
    // f.e. clamped values don't need to re-render
    string text;

    switch (keyCode) {
        // for now hit esc to hide the table views
        case Key::Escape: {
            [self hideTables];
            
            _hudHidden = false;
            [self updateHudVisibility];
            break;
        }
        case Key::V: {
            bool isVertical =
                _buttonStack.orientation == NSUserInterfaceLayoutOrientationVertical;
            isVertical = !isVertical;

            _buttonStack.orientation = isVertical
                                           ? NSUserInterfaceLayoutOrientationVertical
                                           : NSUserInterfaceLayoutOrientationHorizontal;
            text = isVertical ? "Vert UI" : "Horiz UI";

            // just to update toggle state to Off
            isStateChanged = true;
            break;
        }
        case Key::U:
            // this means no image loaded yet
            if (_noImageLoaded) {
                return true;
            }

            _buttonStack.hidden = !_buttonStack.hidden;
            text = _buttonStack.hidden ? "Hide UI" : "Show UI";

            // just to update toggle state to Off
            isStateChanged = true;
            break;

        // rgba channels
        case Key::Num1:
        case Key::R:
            if (![self findButton:"R"].isHidden) {
                TextureChannels &channels = _showSettings->channels;

                if (channels == TextureChannels::ModeR001) {
                    channels = TextureChannels::ModeRGBA;
                    text = "Mask RGBA";
                }
                else {
                    channels = TextureChannels::ModeR001;
                    text = "Mask R001";
                }
                isChanged = true;
            }

            break;

        case Key::Num2:
        case Key::G:
            if (![self findButton:"G"].isHidden) {
                TextureChannels &channels = _showSettings->channels;

                if (channels == TextureChannels::Mode0G01) {
                    channels = TextureChannels::ModeRGBA;
                    text = "Mask RGBA";
                }
                else {
                    channels = TextureChannels::Mode0G01;
                    text = "Mask 0G01";
                }
                isChanged = true;
            }
            break;

        case Key::Num3:
        case Key::B:
            if (![self findButton:"B"].isHidden) {
                TextureChannels &channels = _showSettings->channels;

                if (channels == TextureChannels::Mode00B1) {
                    channels = TextureChannels::ModeRGBA;
                    text = "Mask RGBA";
                }
                else {
                    channels = TextureChannels::Mode00B1;
                    text = "Mask 00B1";
                }

                isChanged = true;
            }
            break;

        case Key::Space: {
            if (![self findButton:" "].isHidden) {
                 Renderer *renderer = (Renderer *)self.delegate;
                
                renderer.playAnimations = !renderer.playAnimations;
                
                text = renderer.playAnimations ? "Play" : "Pause";
                isChanged = true;
                
                self.enableSetNeedsDisplay = !renderer.playAnimations;
                self.paused = !renderer.playAnimations;
            }
            else {
                self.enableSetNeedsDisplay = YES;
                self.paused = YES;
            }
            break;
        }
            
        case Key::Num4:
        case Key::A:
            if (![self findButton:"A"].isHidden) {
                TextureChannels &channels = _showSettings->channels;

                if (channels == TextureChannels::ModeAAA1) {
                    channels = TextureChannels::ModeRGBA;
                    text = "Mask RGBA";
                }
                else {
                    channels = TextureChannels::ModeAAA1;
                    text = "Mask AAA1";
                }

                isChanged = true;
            }
            break;

        case Key::Num6: {
            _showSettings->advanceShapeChannel(isShiftKeyDown);
            
            text = _showSettings->shapeChannelText();
            isChanged = true;
            break;
        }
        case Key::Num5: {
            _showSettings->advanceLightingMode(isShiftKeyDown);
            text = _showSettings->lightingModeText();
            isChanged = true;
            break;
        }
        case Key::T: {
            _showSettings->useTangent = !_showSettings->useTangent;
            if (_showSettings->useTangent)
                text = "Vertex Tangents";
            else
                text = "Fragment Tangents";
            isChanged = true;
            break;
        }
        case Key::E: {
            _showSettings->advanceDebugMode(isShiftKeyDown);
            text = _showSettings->debugModeText();
            isChanged = true;
            break;
        }
        case Key::Slash:  // has ? mark above it
            // display the chars for now
            text =
                "⇧RGBA, O-preview, ⇧E-debug, Show all\n"
                "Hud, ⇧L-reload, ⇧0-fit\n"
                "Checker, ⇧D-block/px grid, Info\n"
                "W-wrap, Premul, N-signed\n"
                "⇧Mip, ⇧Face, ⇧Y-array/slice\n"
                "⇧J-next bundle image\n";

            // just to update toggle state to Off
            isStateChanged = true;
            break;

        case Key::Num0: {  // scale and reset pan
            float zoom;
            // fit image or mip
            if (isShiftKeyDown) {
                zoom = 1.0f;
            }
            else {
                // fit to topmost image
                zoom = _showSettings->zoomFit;
            }

            // This zoom needs to be checked against zoom limits
            // there's a cap on the zoom multiplier.
            // This is reducing zoom which expands the image.
            zoom *= 1.0f / (1 << _showSettings->mipNumber);

            // even if zoom same, still do this since it resets the pan
            _showSettings->zoom = zoom;

            _showSettings->panX = 0.0f;
            _showSettings->panY = 0.0f;

            text = "Scale Image\n";
            if (doPrintPanZoom) {
                string tmp;
                sprintf(tmp,
                        "Pan %.3f,%.3f\n"
                        "Zoom %.2fx\n",
                        _showSettings->panX, _showSettings->panY, _showSettings->zoom);
                text += tmp;
            }

            isChanged = true;

            break;
        }
        // reload key (also a quick way to reset the settings)
        case Key::L:
            [self loadTextureFromURL:self.imageURL];

            // reload at actual size
            if (isShiftKeyDown) {
                _showSettings->zoom = 1.0f;
            }

            text = "Reload Image";
            if (doPrintPanZoom) {
                string tmp;
                sprintf(tmp,
                        "Pan %.3f,%.3f\n"
                        "Zoom %.2fx\n",
                        _showSettings->panX, _showSettings->panY, _showSettings->zoom);
                text += tmp;
            }

            isChanged = true;
            break;

        // P already used for premul
        case Key::O:
            _showSettings->isPreview = !_showSettings->isPreview;
            isChanged = true;
            text = "Preview ";
            text += _showSettings->isPreview ? "On" : "Off";
            break;

        // TODO: might switch c to channel cycle, so could just hit that
        // and depending on the content, it cycles through reasonable channel masks

        // toggle checkerboard for transparency
        case Key::C:
            if (![self findButton:"C"].isHidden) {
                _showSettings->isCheckerboardShown = !_showSettings->isCheckerboardShown;
                isChanged = true;
                text = "Checker ";
                text += _showSettings->isCheckerboardShown ? "On" : "Off";
            }
            break;

        // toggle pixel grid when magnified above 1 pixel, can happen from mipmap
        // changes too
        case Key::D: {
            static int grid = 0;
            static const int kNumGrids = 7;

#define advanceGrid(g, dec) \
    grid = (grid + kNumGrids + (dec ? -1 : 1)) % kNumGrids

            // TODO: display how many blocks there are

            // if block size is 1, then this shouldn't toggle
            _showSettings->isBlockGridShown = false;
            _showSettings->isAtlasGridShown = false;
            _showSettings->isPixelGridShown = false;

            advanceGrid(grid, isShiftKeyDown);

            if (grid == 2 && _showSettings->blockX == 1) {
                // skip it
                advanceGrid(grid, isShiftKeyDown);
            }

            static const uint32_t gridSizes[kNumGrids] = {
                0, 1, 2, 32, 64, 128, 256  // atlas sizes
            };

            if (grid == 0) {
                sprintf(text, "Grid Off");
            }
            else if (grid == 1) {
                _showSettings->isPixelGridShown = true;

                sprintf(text, "Pixel Grid 1x1 On");
            }
            else if (grid == 2) {
                _showSettings->isBlockGridShown = true;

                sprintf(text, "Block Grid %dx%d On", _showSettings->blockX,
                        _showSettings->blockY);
            }
            else {
                _showSettings->isAtlasGridShown = true;

                // want to be able to show altases tht have long entries derived from
                // props but right now just a square grid atlas
                _showSettings->gridSizeX = _showSettings->gridSizeY = gridSizes[grid];

                sprintf(text, "Atlas Grid %dx%d On", _showSettings->gridSizeX,
                        _showSettings->gridSizeY);
            }

            isChanged = true;

            break;
        }
        case Key::S:
            if (![self findButton:"S"].isHidden) {
                // TODO: have drawAllMips, drawAllLevels, drawAllLevelsAndMips
                _showSettings->isShowingAllLevelsAndMips =
                    !_showSettings->isShowingAllLevelsAndMips;
                isChanged = true;
                text = "Show All ";
                text += _showSettings->isShowingAllLevelsAndMips ? "On" : "Off";
            }
            break;

        // toggle hud that shows name and pixel value under the cursor
        // this may require calling setNeedsDisplay on the UILabel as cursor moves
        case Key::H:
            _showSettings->isHudShown = !_showSettings->isHudShown;
            [self updateHudVisibility];
            // isChanged = true;
            text = "Hud ";
            text += _showSettings->isHudShown ? "On" : "Off";
            break;

        // info on the texture, could request info from lib, but would want to cache
        // that info
        case Key::I:
            if (_showSettings->isHudShown) {
                sprintf(text, "%s",
                        isShiftKeyDown ? _showSettings->imageInfoVerbose.c_str()
                                       : _showSettings->imageInfo.c_str());
            }
            // just to update toggle state to Off
            isStateChanged = true;
            break;

        // toggle wrap/clamp
        case Key::W:
            // TODO: cycle through all possible modes (clamp, repeat, mirror-once,
            // mirror-repeat, ...)
            _showSettings->isWrap = !_showSettings->isWrap;
            isChanged = true;
            text = "Wrap ";
            text += _showSettings->isWrap ? "On" : "Off";
            break;

        // toggle signed vs. unsigned
        case Key::N:
            if (![self findButton:"N"].isHidden) {
                _showSettings->isSigned = !_showSettings->isSigned;
                isChanged = true;
                text = "Signed ";
                text += _showSettings->isSigned ? "On" : "Off";
            }
            break;

        // toggle premul alpha vs. unmul
        case Key::P:
            if (![self findButton:"P"].isHidden) {
                _showSettings->isPremul = !_showSettings->isPremul;
                isChanged = true;
                text = "Premul ";
                text += _showSettings->isPremul ? "On" : "Off";
            }
            break;

        case Key::J:
            if (![self findButton:"J"].isHidden) {
                if (_showSettings->isArchive) {
                    if ([self advanceFileFromAchive:!isShiftKeyDown]) {
                        _hudHidden = true;
                        [self updateHudVisibility];
                        
                        isChanged = true;
                        text = "Loaded " + _showSettings->lastFilename;
                    }
                }
                else if (_showSettings->isFolder) {
                    if ([self advanceFileFromFolder:!isShiftKeyDown]) {
                        _hudHidden = true;
                        [self updateHudVisibility];
                        
                        isChanged = true;
                        text = "Loaded " + _showSettings->lastFilename;
                    }
                }
            }
            break;

        // test out different shapes
        case Key::Num8:
            if (_showSettings->meshCount > 1) {
                _showSettings->advanceMeshNumber(isShiftKeyDown);
                text = _showSettings->meshNumberText();
                isChanged = true;
                
                // update shapes table
                [_shapesTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:_showSettings->meshNumber] byExtendingSelection:NO];
                [_shapesTableView scrollRowToVisible:_showSettings->meshNumber];
                
                // show the shapes table
                [self hideTables];
                _shapesTableView.hidden = NO;
                
                // also have to hide hud or it will obscure the visible table
                _hudHidden = true;
                [self updateHudVisibility];
                
                // want it to respond to arrow keys
                [self.window makeFirstResponder: _shapesTableView];
            }
            break;

        // TODO: should probably have these wrap and not clamp to count limits

        // mip up/down
        case Key::M:
            if (_showSettings->mipCount > 1) {
                if (isShiftKeyDown) {
                    _showSettings->mipNumber = MAX(_showSettings->mipNumber - 1, 0);
                }
                else {
                    _showSettings->mipNumber =
                        MIN(_showSettings->mipNumber + 1, _showSettings->mipCount - 1);
                }
                sprintf(text, "Mip %d/%d", _showSettings->mipNumber,
                        _showSettings->mipCount);
                isChanged = true;
            }
            break;

        case Key::F:
            // cube or cube array, but hit s to pick cubearray
            if (_showSettings->faceCount > 1) {
                if (isShiftKeyDown) {
                    _showSettings->faceNumber = MAX(_showSettings->faceNumber - 1, 0);
                }
                else {
                    _showSettings->faceNumber =
                        MIN(_showSettings->faceNumber + 1, _showSettings->faceCount - 1);
                }
                sprintf(text, "Face %d/%d", _showSettings->faceNumber,
                        _showSettings->faceCount);
                isChanged = true;
            }
            break;

        case Key::Y:
            // slice
            if (_showSettings->sliceCount > 1) {
                if (isShiftKeyDown) {
                    _showSettings->sliceNumber = MAX(_showSettings->sliceNumber - 1, 0);
                }
                else {
                    _showSettings->sliceNumber =
                        MIN(_showSettings->sliceNumber + 1, _showSettings->sliceCount - 1);
                }
                sprintf(text, "Slice %d/%d", _showSettings->sliceNumber,
                        _showSettings->sliceCount);
                isChanged = true;
            }
            // array
            else if (_showSettings->arrayCount > 1) {
                if (isShiftKeyDown) {
                    _showSettings->arrayNumber = MAX(_showSettings->arrayNumber - 1, 0);
                }
                else {
                    _showSettings->arrayNumber =
                        MIN(_showSettings->arrayNumber + 1, _showSettings->arrayCount - 1);
                }
                sprintf(text, "Array %d/%d", _showSettings->arrayNumber,
                        _showSettings->arrayCount);
                isChanged = true;
            }
            break;
        default:
            // non-handled key
            return false;
    }

    if (!text.empty()) {
        [self setHudText:text.c_str()];
    }

    if (isChanged || isStateChanged) {
        [self updateUIControlState];
    }

    if (isChanged) {
        self.needsDisplay = YES;
    }
    return true;
}

// Note: docs state that drag&drop should be handled automatically by UTI setup
// via openURLs but I find these calls are needed, or it doesn't work.  Maybe
// need to register for NSRUL instead of NSPasteboardTypeFileURL.  For example,
// in canReadObjectForClasses had to use NSURL.

// drag and drop support
- (NSDragOperation)draggingEntered:(id)sender
{
    if ((NSDragOperationGeneric & [sender draggingSourceOperationMask]) ==
        NSDragOperationGeneric) {
        NSPasteboard *pasteboard = [sender draggingPasteboard];

        bool canReadPasteboardObjects =
            [pasteboard canReadObjectForClasses:@[ [NSURL class] ]
                                        options:nil];

        // don't copy dropped item, want to alias large files on disk without that
        if (canReadPasteboardObjects) {
            return NSDragOperationGeneric;
        }
    }

    // not a drag we can use
    return NSDragOperationNone;
}

- (BOOL)prepareForDragOperation:(id)sender
{
    return YES;
}

- (BOOL)performDragOperation:(id)sender
{
    NSPasteboard *pasteboard = [sender draggingPasteboard];

    NSString *desiredType = [pasteboard availableTypeFromArray:pasteboardTypes];

    if ([desiredType isEqualToString:NSPasteboardTypeFileURL]) {
        // TODO: use readObjects to drag multiple files onto one view
        // load one mip of all those, use smaller mips for thumbnail

        // the pasteboard contains a list of filenames
        NSString *urlString =
            [pasteboard propertyListForType:NSPasteboardTypeFileURL];

        // this turns it into a real path (supposedly works even with sandbox)
        NSURL *url = [NSURL URLWithString:urlString];

        // convert the original path and then back to a url, otherwise reload fails
        // when this file is replaced.
        const char *filename = url.fileSystemRepresentation;
        if (filename == nullptr) {
            KLOGE("kramv", "Fix this drop url returning nil issue");
            return NO;
        }

        NSString *filenameString = [NSString stringWithUTF8String:filename];

        url = [NSURL fileURLWithPath:filenameString];

        if ([self loadTextureFromURL:url]) {
            [self setHudText:""];

            return YES;
        }
    }

    return NO;
}

- (void)updateShapesTable
{
    // no dynamic shapes from archive/folder yet, so init once
    // TODO: tie to default shapes and those in the archive/folder
    // may not want single archive with meshes/textures, so support different
    if (_shapesTableViewController.items.count > 0)
        return;
    
    // setup shapes view too
    [_shapesTableViewController.items removeAllObjects];
    for (uint32_t i = 0; i < _showSettings->meshCount; ++i) {
        [_shapesTableViewController.items addObject: [NSString stringWithUTF8String: _showSettings->meshNumberName(i)]];
    }
    [_shapesTableView reloadData];
}

- (BOOL)loadArchive:(const char *)zipFilename
{
    _zipMmap.close();
    if (!_zipMmap.open(zipFilename)) {
        return NO;
    }

    // Note: if mmap fails, could read entire zip into memory
    // and then still use the same code below.

    if (!_zip.openForRead(_zipMmap.data(), _zipMmap.dataLength())) {
        return NO;
    }

    // filter out unsupported extensions
    vector<string> extensions = {
        ".ktx", ".ktx2", ".png" // textures
#if USE_GLTF
        , ".glb", ".gltf" // models
#endif
    };
    
    _zip.filterExtensions(extensions);

    // don't switch to empty archive
    if (_zip.zipEntrys().empty()) {
        return NO;
    }

    // load the first entry in the archive
    _fileArchiveIndex = 0;
    
    // copy names into the files view
    [_tableViewController.items removeAllObjects];
    for (const auto& entry: _zip.zipEntrys()) {
        const char *filenameShort = toFilenameShort(entry.filename);
        [_tableViewController.items addObject: [NSString stringWithUTF8String: filenameShort]];
    }
    [_tableView reloadData];
    
    // set selection
    [_tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:_fileArchiveIndex] byExtendingSelection:NO];
    [_tableView scrollRowToVisible:_fileArchiveIndex];
    
    // want it to respond to arrow keys
    [self.window makeFirstResponder: _tableView];
    
    [self updateShapesTable];
    
    // hack to see table
    [self hideTables];
    
    return YES;
}

- (BOOL)advanceFileFromAchive:(BOOL)increment
{
    if ((!_zipMmap.data()) || _zip.zipEntrys().empty()) {
        // no archive loaded or it's empty
        return NO;
    }
    size_t numEntries = _zip.zipEntrys().size();

    if (increment)
        _fileArchiveIndex++;
    else
        _fileArchiveIndex += numEntries - 1;  // back 1

    _fileArchiveIndex = _fileArchiveIndex % numEntries;

    // set selection
    [_tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:_fileArchiveIndex] byExtendingSelection:NO];
    [_tableView scrollRowToVisible:_fileArchiveIndex];
    
    // want it to respond to arrow keys
    [self.window makeFirstResponder: _tableView];
    
    // show the files table
    [self hideTables];
    _tableView.hidden = NO;
    
    // also have to hide hud or it will obscure the visible table
    _hudHidden = true;
    [self updateHudVisibility];
    
    return [self loadFileFromArchive];
}

- (BOOL)advanceFileFromFolder:(BOOL)increment
{
    if (_folderFiles.empty()) {
        // no archive loaded
        return NO;
    }

    size_t numEntries = _folderFiles.size();
    if (increment)
        _fileFolderIndex++;
    else
        _fileFolderIndex += numEntries - 1;  // back 1

    _fileFolderIndex = _fileFolderIndex % numEntries;

    // set selection
    [_tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:_fileFolderIndex] byExtendingSelection:NO];
    [_tableView scrollRowToVisible:_fileFolderIndex];
    
    // want it to respond to arrow keys
    [self.window makeFirstResponder: _tableView];
    
    // show the files table
    [self hideTables];
    _tableView.hidden = NO;
    
    _hudHidden = true;
    [self updateHudVisibility];
    
    return [self loadFileFromFolder];
}

- (BOOL)setImageFromSelection:(NSInteger)index {
    if (_zipMmap.data() && !_zip.zipEntrys().empty()) {
        if (_fileArchiveIndex != index) {
            _fileArchiveIndex = index;
            return [self loadFileFromArchive];
        }
    }

    if (!_folderFiles.empty()) {
        if (_fileFolderIndex != index) {
            _fileFolderIndex = index;
            return [self loadFileFromFolder];
        }
    }
    return NO;
}

- (BOOL)setShapeFromSelection:(NSInteger)index {
    if (_showSettings->meshNumber != index) {
        _showSettings->meshNumber = index;
        self.needsDisplay = YES;
        return YES;
    }
    return NO;
}

- (BOOL)findFilenameInFolders:(const string &)filename
{
    // TODO: binary search for the filename in the array, but would have to be in
    // same directory

    bool isFound = false;
    for (const auto &search : _folderFiles) {
        if (search == filename) {
            isFound = true;
            break;
        }
    }
    return isFound;
}

- (BOOL)loadFileFromFolder
{
    // now lookup the filename and data at that entry
    const char *filename = _folderFiles[_fileFolderIndex].c_str();
    string fullFilename = filename;
    auto timestamp = FileHelper::modificationTimestamp(filename);
    
    bool isModel =
        endsWithExtension(filename, ".gltf") ||
        endsWithExtension(filename, ".gtb");
    if (isModel)
        return [self loadModelFile:nil filename:filename];
    
    // have already filtered filenames out, so this should never get hit
    bool isPNG = isPNGFilename(filename);
    if (!(isPNG ||
          endsWithExtension(filename, ".ktx") ||
          endsWithExtension(filename, ".ktx2"))) {
        return NO;
    }

    const char *ext = strrchr(filename, '.');

    // first only do this on albedo/diffuse textures

    // find matching png
    string search = "-a";
    search += ext;

    auto searchPos = fullFilename.find(search);
    bool isFound = searchPos != string::npos;

    if (!isFound) {
        search = "-d";
        search += ext;

        searchPos = fullFilename.find(search);
        isFound = searchPos != string::npos;
    }

    bool isSrgb = isFound;

    string normalFilename;
    bool hasNormal = false;

    if (isFound) {
        normalFilename = fullFilename;
        normalFilename = normalFilename.erase(searchPos);
        normalFilename += "-n";
        normalFilename += ext;

        hasNormal = [self findFilenameInFolders:normalFilename];
    }

    //-------------------------------

    KTXImage image;
    KTXImageData imageDataKTX;

    KTXImage imageNormal;
    KTXImageData imageNormalDataKTX;

    // this requires decode and conversion to RGBA8u
    if (!imageDataKTX.open(fullFilename.c_str(), image)) {
        return NO;
    }

    if (hasNormal &&
        imageNormalDataKTX.open(normalFilename.c_str(), imageNormal)) {
        // shaders only pull from albedo + normal on these texture types
        if (imageNormal.textureType == image.textureType &&
            (imageNormal.textureType == MyMTLTextureType2D ||
             imageNormal.textureType == MyMTLTextureType2DArray)) {
            // hasNormal = true;
        }
        else {
            hasNormal = false;
        }
    }

    if (isPNG && isSrgb) {
        image.pixelFormat = MyMTLPixelFormatRGBA8Unorm_sRGB;
    }

    
    Renderer *renderer = (Renderer *)self.delegate;
    [renderer releaseAllPendingTextures];
    
    if (![renderer loadTextureFromImage:fullFilename.c_str()
                              timestamp:timestamp
                                  image:image
                            imageNormal:hasNormal ? &imageNormal : nullptr
                              isArchive:NO]) {
        return NO;
    }

    //-------------------------------

    // set title to filename, chop this to just file+ext, not directory
    const char *filenameShort = strrchr(filename, '/');
    if (filenameShort == nullptr) {
        filenameShort = filename;
    }
    else {
        filenameShort += 1;
    }

    // was using subtitle, but that's macOS 11.0 feature.
    string title = "kramv - ";
    title += formatTypeName(_showSettings->originalFormat);
    title += " - ";
    title += filenameShort;

    self.window.title = [NSString stringWithUTF8String:title.c_str()];

    // doesn't set imageURL or update the recent document menu

    // show the controls
    if (_noImageLoaded) {
        _buttonStack.hidden = NO;  // show controls
        _noImageLoaded = NO;
    }

    _showSettings->isArchive = false;
    _showSettings->isFolder = true;

    // show/hide button
    [self updateUIAfterLoad];
    
    self.needsDisplay = YES;
    return YES;
}

- (BOOL)loadFileFromArchive
{
    // now lookup the filename and data at that entry
    const auto& entry = _zip.zipEntrys()[_fileArchiveIndex];
    const char* filename = entry.filename;
    string fullFilename = filename;
    double timestamp = (double)entry.modificationDate;

    bool isModel =
        endsWithExtension(filename, ".gltf") ||
        endsWithExtension(filename, ".gtb");
    if (isModel)
        return [self loadModelFile:nil filename:filename];
    
    //--------
    
    bool isPNG = isPNGFilename(filename);

    if (!(isPNG ||
          endsWithExtension(filename, ".ktx") ||
          endsWithExtension(filename, ".ktx2"))) {
        return NO;
    }

    const char *ext = strrchr(filename, '.');

    // first only do this on albedo/diffuse textures

    string search = "-a";
    search += ext;

    auto searchPos = fullFilename.find(search);
    bool isFound = searchPos != string::npos;

    if (!isFound) {
        search = "-d";
        search += ext;

        searchPos = fullFilename.find(search);
        isFound = searchPos != string::npos;
    }

    bool isSrgb = isFound;

    //---------------------------

    const uint8_t *imageData = nullptr;
    uint64_t imageDataLength = 0;

    const uint8_t *imageNormalData = nullptr;
    uint64_t imageNormalDataLength = 0;

    // search for main file - can be albedo or normal
    if (!_zip.extractRaw(filename, &imageData, imageDataLength)) {
        return NO;
    }

    // search for normal map in the same archive
    string normalFilename;
    bool hasNormal = false;

    if (isFound) {
        normalFilename = fullFilename;
        normalFilename = normalFilename.erase(searchPos);
        normalFilename += "-n";
        normalFilename += ext;

        hasNormal = _zip.extractRaw(normalFilename.c_str(), &imageNormalData,
                                    imageNormalDataLength);
    }

    //---------------------------

    // files in archive are just offsets into the mmap
    // That's why we can't just pass filenames to the renderer
    KTXImage image;
    KTXImageData imageDataKTX;

    KTXImage imageNormal;
    KTXImageData imageNormalDataKTX;

    if (!imageDataKTX.open(imageData, imageDataLength, image)) {
        return NO;
    }

    if (hasNormal && imageNormalDataKTX.open(
                         imageNormalData, imageNormalDataLength, imageNormal)) {
        // shaders only pull from albedo + normal on these texture types
        if (imageNormal.textureType == image.textureType &&
            (imageNormal.textureType == MyMTLTextureType2D ||
             imageNormal.textureType == MyMTLTextureType2DArray)) {
            // hasNormal = true;
        }
        else {
            hasNormal = false;
        }
    }

    if (isPNG && isSrgb) {
        image.pixelFormat = MyMTLPixelFormatRGBA8Unorm_sRGB;
    }

    Renderer *renderer = (Renderer *)self.delegate;
    [renderer releaseAllPendingTextures];
    
    if (![renderer loadTextureFromImage:fullFilename.c_str()
                              timestamp:(double)timestamp
                                  image:image
                            imageNormal:hasNormal ? &imageNormal : nullptr
                              isArchive:YES]) {
        return NO;
    }

    //---------------------------------

    // set title to filename, chop this to just file+ext, not directory
    const char *filenameShort = strrchr(filename, '/');
    if (filenameShort == nullptr) {
        filenameShort = filename;
    }
    else {
        filenameShort += 1;
    }

    // was using subtitle, but that's macOS 11.0 feature.
    string title = "kramv - ";
    title += formatTypeName(_showSettings->originalFormat);
    title += " - ";
    title += filenameShort;

    self.window.title = [NSString stringWithUTF8String:title.c_str()];

    // doesn't set imageURL or update the recent document menu

    // show the controls
    if (_noImageLoaded) {
        _buttonStack.hidden = NO;  // show controls
        _noImageLoaded = NO;
    }

    _showSettings->isArchive = true;
    _showSettings->isFolder = false;

    // show/hide button
    [self updateUIAfterLoad];

    
    self.needsDisplay = YES;
    return YES;
}

- (BOOL)loadTextureFromURL:(NSURL *)url
{
    // NSLog(@"LoadTexture");

    // turn back on the hud if was in a list view
    _hudHidden = false;
    [self updateHudVisibility];
    
    const char *filename = url.fileSystemRepresentation;
    if (filename == nullptr) {
        // Fixed by converting dropped urls into paths then back to a url.
        // When file replaced the drop url is no longer valid.
        KLOGE("kramv", "Fix this load url returning nil issue");
        return NO;
    }
    
    Renderer *renderer = (Renderer *)self.delegate;
    
    // folders can have a . in them f.e. 2.0/blah/...
    bool isDirectory = url.hasDirectoryPath;
    
    // this likely means it's a local file directory
    if (isDirectory) {
        // make list of all file in the directory

        if (!self.imageURL || (!([self.imageURL isEqualTo:url]))) {
            NSDirectoryEnumerator *directoryEnumerator =
                [[NSFileManager defaultManager]
                               enumeratorAtURL:url
                    includingPropertiesForKeys:[NSArray array]
                                       options:0
                                  errorHandler:  // nil
                                      ^BOOL(NSURL *urlArg, NSError *error) {
                                          macroUnusedVar(urlArg);
                                          macroUnusedVar(error);

                                          // handle error
                                          return NO;
                                      }];

            vector<string> files;
#if USE_GLTF
            // only display models in folder if found, ignore the png/jpg files
            while (NSURL *fileOrDirectoryURL = [directoryEnumerator nextObject]) {
                const char *name = fileOrDirectoryURL.fileSystemRepresentation;

                bool isGLTF = endsWithExtension(name, ".gltf");
                bool isGLB = endsWithExtension(name, ".glb");
                if (isGLTF || isGLB)
                {
                    files.push_back(name);
                }
            }
#endif

            // don't change to this folder if it's devoid of content
            if (files.empty()) {
#if USE_GLTF
                // reset the enumerator
                directoryEnumerator =
                    [[NSFileManager defaultManager]
                                   enumeratorAtURL:url
                        includingPropertiesForKeys:[NSArray array]
                                           options:0
                                      errorHandler:  // nil
                                          ^BOOL(NSURL *urlArg, NSError *error) {
                                              macroUnusedVar(urlArg);
                                              macroUnusedVar(error);

                                              // handle error
                                              return NO;
                                          }];
#endif
                while (NSURL *fileOrDirectoryURL = [directoryEnumerator nextObject]) {
                    const char *name = fileOrDirectoryURL.fileSystemRepresentation;

                    // filter only types that are supported
                    bool isPNG = isPNGFilename(name);
                    bool isKTX = endsWithExtension(name, ".ktx");
                    bool isKTX2 = endsWithExtension(name, ".ktx2");
    
                    if (isPNG || isKTX || isKTX2)
                    {
                        files.push_back(name);
                    }
                }
            }
            
            if (files.empty()) {
                return NO;
            }

            // add it to recent docs
            NSDocumentController *dc =
                [NSDocumentController sharedDocumentController];
            [dc noteNewRecentDocumentURL:url];

            // sort them
#if USE_EASTL
            NAMESPACE_STL::quick_sort(files.begin(), files.end());
#else
            NAMESPACE_STL::sort(files.begin(), files.end());
#endif
            // replicate archive logic below

            self.imageURL = url;

            // preserve old folder
            string existingFilename;
            if (_fileFolderIndex < (int32_t)_folderFiles.size())
                existingFilename = _folderFiles[_fileFolderIndex];
            else
                _fileFolderIndex = 0;

            _folderFiles = files;

            // TODO: preserve filename before load, and restore that index, by finding
            // that name in refreshed folder list

            if (!existingFilename.empty()) {
                uint32_t index = 0;
                for (const auto &fileIt : _folderFiles) {
                    if (fileIt == existingFilename) {
                        break;
                    }
                }

                _fileFolderIndex = index;
            }
            
            [_tableViewController.items removeAllObjects];
            for (const auto& file: files) {
                const char *filenameShort = toFilenameShort(file.c_str());
                [_tableViewController.items addObject: [NSString stringWithUTF8String: filenameShort]];
            }
            [_tableView reloadData];
            
            [_tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:_fileFolderIndex] byExtendingSelection:NO];
            [_tableView scrollRowToVisible:_fileFolderIndex];
            
            [self updateShapesTable];
            [self hideTables];
        }

        // now load image from directory
        _showSettings->isArchive = false;
        _showSettings->isFolder = true;

        
        // now load the file at the index
        setErrorLogCapture(true);

        BOOL success = [self loadFileFromFolder];

        if (!success) {
            // get back error text from the failed load
            string errorText;
            getErrorLogCaptureText(errorText);
            setErrorLogCapture(false);

            const string &folder = _folderFiles[_fileFolderIndex];

            // prepend filename
            string finalErrorText;
            append_sprintf(finalErrorText, "Could not load from folder:\n %s\n",
                           folder.c_str());
            finalErrorText += errorText;

            [self setHudText:finalErrorText.c_str()];
        }

        setErrorLogCapture(false);
        return success;
    }

    //-------------------
    
    if (endsWithExtension(filename, ".metallib")) {
        if ([renderer hotloadShaders:filename]) {
            NSURL *metallibFileURL =
                [NSURL fileURLWithPath:[NSString stringWithUTF8String:filename]];

            // add to recent docs, so can reload quickly
            NSDocumentController *dc =
                [NSDocumentController sharedDocumentController];
            [dc noteNewRecentDocumentURL:metallibFileURL];

            return YES;
        }
        return NO;
    }

    // file is not a supported extension
    if (!(
          // archive
          endsWithExtension(filename, ".zip") ||
          
          // images
          isPNGFilename(filename) ||
          endsWithExtension(filename, ".ktx") ||
          endsWithExtension(filename, ".ktx2") ||
          
          // models
          endsWithExtension(filename, ".gltf") ||
          endsWithExtension(filename, ".glb")
        ))
    {
        string errorText =
            "Unsupported file extension, must be .zip, .png, .ktx, .ktx2, .gltf, .glb\n";

        string finalErrorText;
        append_sprintf(finalErrorText, "Could not load from file:\n %s\n",
                       filename);
        finalErrorText += errorText;

        [self setHudText:finalErrorText.c_str()];
        return NO;
    }

    if (endsWithExtension(filename, ".gltf") ||
        endsWithExtension(filename, ".glb"))
    {
        return [self loadModelFile:url filename:nullptr];
    }
    
    // for now, knock out model if loading an image
    // TODO: might want to unload even before loading a new model
    [renderer unloadModel];
    
    //-------------------

    if (endsWithExtension(filename, ".zip")) {
        auto archiveTimestamp = FileHelper::modificationTimestamp(filename);

        if (!self.imageURL || (!([self.imageURL isEqualTo:url])) ||
            (self.lastArchiveTimestamp != archiveTimestamp)) {
            // copy this out before it's replaced
            string existingFilename;
            if (_fileArchiveIndex < (int32_t)_zip.zipEntrys().size())
                existingFilename = _zip.zipEntrys()[_fileArchiveIndex].filename;
            else
                _fileArchiveIndex = 0;

            BOOL isArchiveLoaded = [self loadArchive:filename];
            if (!isArchiveLoaded) {
                return NO;
            }

            // store the archive url
            self.imageURL = url;
            self.lastArchiveTimestamp = archiveTimestamp;

            // add it to recent docs
            NSDocumentController *dc =
                [NSDocumentController sharedDocumentController];
            [dc noteNewRecentDocumentURL:url];

            // now reload the filename if needed
            if (!existingFilename.empty()) {
                const ZipEntry *formerEntry = _zip.zipEntry(existingFilename.c_str());
                if (formerEntry) {
                    // lookup the index in the remapIndices table
                    _fileArchiveIndex =
                        (uintptr_t)(formerEntry - &_zip.zipEntrys().front());
                }
                else {
                    _fileArchiveIndex = 0;
                }
            }
        }

        setErrorLogCapture(true);

        BOOL success = [self loadFileFromArchive];

        if (!success) {
            // get back error text from the failed load
            string errorText;
            getErrorLogCaptureText(errorText);
            setErrorLogCapture(false);

            const auto &entry = _zip.zipEntrys()[_fileArchiveIndex];
            const char *archiveFilename = entry.filename;

            // prepend filename
            string finalErrorText;
            append_sprintf(finalErrorText, "Could not load from archive:\n %s\n",
                           archiveFilename);
            finalErrorText += errorText;

            [self setHudText:finalErrorText.c_str()];
        }

        setErrorLogCapture(false);
        return success;
    }

    return [self loadImageFile:url];
}

-(BOOL)loadModelFile:(NSURL*)url filename:(const char*)filename
{
#if USE_GLTF
    // Right now can only load these if they are embedded, since sandbox will
    // fail to load related .png and .bin files.  There's a way to opt into
    // related items, but they must all be named the same.  I think if folder
    // instead of the file is selected, then could search and find the gltf files
    // and the other files.

    //----------------------
    // These assets should be combined into a single hierarchy, and be able to
    // save out a scene with all of them in a single scene.  But that should
    // probably reference original content in case it's updated.
    
    Renderer *renderer = (Renderer *)self.delegate;
    [renderer releaseAllPendingTextures];
    
    setErrorLogCapture(true);

    // set title to filename, chop this to just file+ext, not directory
    if (url != nil)
        filename = url.fileSystemRepresentation;
    const char* filenameShort = toFilenameShort(filename);

    NSURL* gltfFileURL =
        [NSURL fileURLWithPath:[NSString stringWithUTF8String:filename]];

    BOOL success = [renderer loadModel:gltfFileURL];
    
    // TODO: split this off to a completion handler, since loadModel is async
    // and should probably also have a cancellation (or counter)
    
    // show/hide button
    [self updateUIAfterLoad];
    
    if (!success) {
        string errorText;
        getErrorLogCaptureText(errorText);
        setErrorLogCapture(false);
        
        string finalErrorText;
        append_sprintf(finalErrorText, "Could not load model from file:\n %s\n",
                       filename);
        finalErrorText += errorText;

        [self setHudText:finalErrorText.c_str()];
        
        return NO;
    }

    // was using subtitle, but that's macOS 11.0 feature.
    string title = "kramv - ";
    title += filenameShort;

    self.window.title = [NSString stringWithUTF8String:title.c_str()];

    // if url is nil, then loading out of archive or folder
    // and don't want to save that or set imageURL
    if (url != nil)
    {
        // add to recent docs, so can reload quickly
        NSDocumentController *dc =
            [NSDocumentController sharedDocumentController];
        [dc noteNewRecentDocumentURL:gltfFileURL];

        // TODO: not really an image
        self.imageURL = gltfFileURL;
        
        // this may be loading out of folder/archive, but if url passed then it isn't
        _showSettings->isArchive = false;
        _showSettings->isFolder = false;
        
        // no need for file table on single files
        _tableView.hidden = YES;
    }
    
    // show the controls
    if (_noImageLoaded) {
        _buttonStack.hidden = NO;  // show controls
        _noImageLoaded = NO;
    }

    setErrorLogCapture(false);

    self.needsDisplay = YES;

    return success;
#else
    return NO;
#endif
}

-(BOOL)loadImageFile:(NSURL*)url
{
    Renderer *renderer = (Renderer *)self.delegate;
    setErrorLogCapture(true);

    // set title to filename, chop this to just file+ext, not directory
    const char* filename = url.fileSystemRepresentation;
    const char* filenameShort = toFilenameShort(filename);
    
    BOOL success = [renderer loadTexture:url];

    if (!success) {
        // get back error text from the failed load
        string errorText;
        getErrorLogCaptureText(errorText);
        setErrorLogCapture(false);

        // prepend filename
        string finalErrorText;
        append_sprintf(finalErrorText, "Could not load from file\n %s\n", filename);
        finalErrorText += errorText;

        [self setHudText:finalErrorText.c_str()];
        return NO;
    }
    setErrorLogCapture(false);

    // was using subtitle, but that's macOS 11.0 feature.
    string title = "kramv - ";
    title += formatTypeName(_showSettings->originalFormat);
    title += " - ";
    title += filenameShort;

    self.window.title = [NSString stringWithUTF8String:title.c_str()];

    // topmost entry will be the recently opened document
    // some entries may go stale if directories change, not sure who validates the
    // list

    // add to recent document menu
    NSDocumentController *dc = [NSDocumentController sharedDocumentController];
    [dc noteNewRecentDocumentURL:url];

    self.imageURL = url;

    // show the controls
    if (_noImageLoaded) {
        _buttonStack.hidden = NO;  // show controls
        _noImageLoaded = NO;
    }

    _showSettings->isArchive = false;
    _showSettings->isFolder = false;

    // show/hide button
    [self updateUIAfterLoad];
    // no need for file table on single files
    _tableView.hidden = YES;
    
    self.needsDisplay = YES;
    return YES;
}

- (void)setupUI
{
    // Load the basic shapes table once
    [self updateShapesTable];
    [self hideTables];
}

- (void)concludeDragOperation:(id)sender
{
    // did setNeedsDisplay, but already doing that in loadTextureFromURL
}

// this doesn't seem to enable New.  Was able to get "Open" to highlight by
// setting NSDocument as class for doc types.
// https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/EventOverview/EventArchitecture/EventArchitecture.html
#if 0
/*
// "New"" calls this
- (__kindof NSDocument *)openUntitledDocumentAndDisplay:(BOOL)displayDocument
                                                  error:(NSError * _Nullable *)outError
{
    // TODO: this should add an empty MyMTKView and can drag/drop to that.
    // Need to track images and data dropped per view then.
    return nil;
}

// "Open File" calls this
- (void)openDocumentWithContentsOfURL:(NSURL *)url
                              display:(BOOL)displayDocument
                    completionHandler:(void (^)(NSDocument *document, BOOL documentWasAlreadyOpen, NSError *error))completionHandler
{
    [self loadTextureFromURL:url];
}

- (IBAction)openDocument {
    // calls openDocumentWithContentsOfURL above
}

- (IBAction)newDocument {
    // calls openUntitledDocumentAndDisplay above
}
*/
#endif

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
    if (notification.object == _tableView)
    {
        // image
        NSInteger selectedRow = [_tableView selectedRow];
        [self setImageFromSelection:selectedRow];
    }
    else if (notification.object == _shapesTableView)
    {
        // shape
        NSInteger selectedRow = [_shapesTableView selectedRow];
        [self setShapeFromSelection:selectedRow];
    }
}

- (void)addNotifications
{
    // listen for the selection change messages
    [[NSNotificationCenter defaultCenter] addObserver:self
                                              selector:@selector(tableViewSelectionDidChange:)
                                                  name:NSTableViewSelectionDidChangeNotification object:nil];
}

- (void)removeNotifications
{
    // listen for the selection change messages
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


- (BOOL)acceptsFirstResponder
{
    return YES;
}

@end

//-------------

// Our macOS view controller.
@interface GameViewController : NSViewController

@end

@implementation GameViewController {
    MyMTKView *_view;

    Renderer *_renderer;

    NSTrackingArea *_trackingArea;
}

- (void)viewWillDisappear
{
    [_view removeNotifications];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    _view = (MyMTKView *)self.view;

    // have to disable this since reading back from textures
    // that slows the blit to the screen
    _view.framebufferOnly = NO;

    _view.device = MTLCreateSystemDefaultDevice();

    if (!_view.device) {
        return;
    }

    _renderer = [[Renderer alloc] initWithMetalKitView:_view
                                              settings:_view.showSettings];

    
    // https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/EventOverview/TrackingAreaObjects/TrackingAreaObjects.html
    // this is better than requesting mousemoved events, they're only sent when
    // cursor is inside
    _trackingArea = [[NSTrackingArea alloc]
        initWithRect:_view.bounds
             options:(NSTrackingMouseEnteredAndExited | NSTrackingMouseMoved |

                      // NSTrackingActiveWhenFirstResponder
                      NSTrackingActiveInActiveApp
                      // NSTrackingActiveInKeyWindow
                      )
               owner:_view
            userInfo:nil];
    [_view addTrackingArea:_trackingArea];

    // programmatically add some buttons
    // think limited to 11 viewws before they must be wrapepd in a container.
    // That's how SwiftUI was.
    [_view addNotifications];
    
    [_view setupUI];
    
    // original sample code was sending down _view.bounds.size, but need
    // drawableSize this was causing all sorts of inconsistencies
    [_renderer mtkView:_view drawableSizeWillChange:_view.drawableSize];

    _view.delegate = _renderer;
}



@end

//-------------

int main(int argc, const char *argv[])
{
    @autoreleasepool {
        // Setup code that might create autoreleased objects goes here.
    }
    return NSApplicationMain(argc, argv);
}
