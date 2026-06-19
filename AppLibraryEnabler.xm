/* App Library Enabler - Enable App Library on iPadOS
 * Copyright (C) 2020 Tomasz Poliszuk
 *
 * App Library Enabler is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License.
 *
 * App Library Enabler is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with App Library Enabler. If not, see <https://www.gnu.org/licenses/>.
 */


#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <string.h>

@interface UIView (AppLibraryEnabler)
- (id)_viewControllerForAncestor;
@end

@interface SBIconView : UIView
@end

@interface SBHSearchBar : UIView
@property (assign,nonatomic) UIEdgeInsets searchTextFieldHorizontalEdgeInsets;
@end

@protocol SBHOccludable
@end

@interface SBHomeScreenOverlayViewController : UIViewController
@property (nonatomic, retain) UIViewController<SBHOccludable> *rightSidebarViewController;
@property (nonatomic, retain) NSLayoutConstraint *contentWidthConstraint;
@end

@interface MTMaterialView : UIView
@end

@interface SBHLibrarySearchController : UIViewController
@end

@interface SBNestingViewController : UIViewController
@end
@interface SBFolderController : SBNestingViewController
@end
@interface SBHLibraryPodFolderController : SBFolderController
@property (nonatomic,readonly) UIView * containerView;
@end

@interface SBHLibraryPodFolderController (AppLibraryEnabler)
+ (id)iconLocation;
@end

struct SBHIconGridSize {
	unsigned short columns;
	unsigned short rows;
};

struct SBHIconGridSizeClassSizes {
	struct SBHIconGridSize small;
	struct SBHIconGridSize medium;
	struct SBHIconGridSize large;
	struct SBHIconGridSize extraLarge;
};

@interface SBIconListGridLayoutConfiguration : NSObject
@property (nonatomic) unsigned long long numberOfLandscapeColumns;
@property (nonatomic) unsigned long long numberOfLandscapeRows;
@property (nonatomic) unsigned long long numberOfPortraitColumns;
@property (nonatomic) unsigned long long numberOfPortraitRows;
@property (nonatomic) CGSize listSizeForIconSpacingCalculation;
@property (nonatomic) UIEdgeInsets landscapeLayoutInsets;
@property (nonatomic) UIEdgeInsets portraitLayoutInsets;
@property (nonatomic) struct SBHIconGridSizeClassSizes iconGridSizeClassSizes;
@end

@interface SBFolder : NSObject
- (struct SBHIconGridSize)listGridSize;
@end

@interface SBHLibraryCategoryFolder : SBFolder
- (id)initWithDisplayName:(id)displayName maxListCount:(unsigned long long)maxListCount listGridSize:(struct SBHIconGridSize)listGridSize libraryCategoryIdentifier:(id)libraryCategoryIdentifier;
@end

@interface SBHLibraryCategory : NSObject
- (SBHLibraryCategoryFolder *)expandedPodFolder;
@end

@interface SBIconListModel : NSObject
@property (nonatomic, readonly) SBFolder *folder;
@property (nonatomic, readonly) unsigned long long numberOfIcons;
- (struct SBHIconGridSize)gridSize;
- (id)gridCellInfoForGridSize:(struct SBHIconGridSize)gridSize options:(unsigned long long)options;
@end

static BOOL ALEConfiguringLibraryRootLayout = NO;
static char ALEExpandedLibraryCategoryFolderKey;
static NSUInteger ALEBuildingExpandedLibraryCategoryFolderDepth = 0;

static id ALEValueForKey(id object, NSString *key) {
	if (!object || !key) {
		return nil;
	}

	@try {
		return [object valueForKey:key];
	} @catch (NSException *exception) {
		return nil;
	}
}

static BOOL ALEObjectIsKindOfClassNamed(id object, NSString *className) {
	if (!object || !className) {
		return NO;
	}

	Class cls = NSClassFromString(className);
	return cls ? [object isKindOfClass:cls] : [NSStringFromClass([object class]) isEqualToString:className];
}

static BOOL ALEIsLibraryController(id controller) {
	if (!controller) {
		return NO;
	}

	if (ALEObjectIsKindOfClassNamed(controller, @"SBHLibraryViewController")) {
		return YES;
	}

	id avocadoViewController = ALEValueForKey(controller, @"avocadoViewController");
	if (avocadoViewController && avocadoViewController != controller) {
		return ALEIsLibraryController(avocadoViewController);
	}

	return NO;
}

static BOOL ALEOverlayShowsAppLibrary(SBHomeScreenOverlayViewController *overlayController) {
	id rightSidebarViewController = ALEValueForKey(overlayController, @"rightSidebarViewController");
	id contentViewController = ALEValueForKey(overlayController, @"contentViewController");

	return ALEIsLibraryController(rightSidebarViewController) || ALEIsLibraryController(contentViewController);
}

static BOOL ALEObjectsEqual(id firstObject, id secondObject) {
	if (firstObject == secondObject) {
		return YES;
	}
	if (!firstObject || !secondObject || ![firstObject respondsToSelector:@selector(isEqual:)]) {
		return NO;
	}

	return [firstObject isEqual:secondObject];
}

static BOOL ALEIsLibraryRootIconLocation(id iconLocation) {
	Class podFolderControllerClass = NSClassFromString(@"SBHLibraryPodFolderController");
	if (!podFolderControllerClass || ![podFolderControllerClass respondsToSelector:@selector(iconLocation)]) {
		return NO;
	}

	return ALEObjectsEqual(iconLocation, [podFolderControllerClass iconLocation]);
}

static BOOL ALEIsLibraryCategoriesRootFolder(SBFolder *folder) {
	return ALEObjectIsKindOfClassNamed(folder, @"SBHLibraryCategoriesRootFolder");
}

static CGSize ALECurrentInterfaceSize(void) {
	UIWindow *keyWindow = ALEValueForKey([UIApplication sharedApplication], @"keyWindow");
	if (keyWindow && !CGSizeEqualToSize(keyWindow.bounds.size, CGSizeZero)) {
		return keyWindow.bounds.size;
	}

	NSArray *windows = ALEValueForKey([UIApplication sharedApplication], @"windows");
	if ([windows isKindOfClass:[NSArray class]]) {
		for (UIWindow *window in windows) {
			if ([window isKindOfClass:[UIWindow class]] && !CGSizeEqualToSize(window.bounds.size, CGSizeZero)) {
				return window.bounds.size;
			}
		}
	}

	return [UIScreen mainScreen].bounds.size;
}

static CGFloat ALEInterfaceWidthForView(UIView *view) {
	if (view && CGRectGetWidth(view.window.bounds) > 0) {
		return CGRectGetWidth(view.window.bounds);
	}
	if (view && CGRectGetWidth(view.superview.bounds) > 0) {
		return CGRectGetWidth(view.superview.bounds);
	}
	if (view && CGRectGetWidth(view.bounds) > 0) {
		return CGRectGetWidth(view.bounds);
	}

	return ALECurrentInterfaceSize().width;
}

static BOOL ALEIsLandscapeScreen(void) {
	CGSize interfaceSize = ALECurrentInterfaceSize();
	if (interfaceSize.width != interfaceSize.height) {
		return interfaceSize.width > interfaceSize.height;
	}

	NSNumber *orientationValue = ALEValueForKey([UIApplication sharedApplication], @"statusBarOrientation");
	if ([orientationValue isKindOfClass:[NSNumber class]]) {
		UIInterfaceOrientation orientation = (UIInterfaceOrientation)[orientationValue integerValue];
		if (orientation != UIInterfaceOrientationUnknown) {
			return UIInterfaceOrientationIsLandscape(orientation);
		}
	}

	return interfaceSize.width > interfaceSize.height;
}

static unsigned long long ALELibraryRootPodColumns(void) {
	return ALEIsLandscapeScreen() ? 4 : 3;
}

static struct SBHIconGridSize ALELibraryRootGridSize(struct SBHIconGridSize originalGridSize) {
	struct SBHIconGridSize gridSize = originalGridSize;
	unsigned long long podColumns = ALELibraryRootPodColumns();
	unsigned long long podRows = ALEIsLandscapeScreen() ? 4 : 5;

	gridSize.columns = MAX(gridSize.columns, (unsigned short)(podColumns * 2));
	gridSize.rows = MAX(gridSize.rows, (unsigned short)(podRows * 2));
	return gridSize;
}

static struct SBHIconGridSize ALEExpandedLibraryCategoryGridSize(struct SBHIconGridSize originalGridSize) {
	struct SBHIconGridSize gridSize = originalGridSize;

	if (ALEIsLandscapeScreen()) {
		gridSize.columns = MAX(gridSize.columns, (unsigned short)6);
		gridSize.rows = MAX(gridSize.rows, (unsigned short)4);
	} else {
		gridSize.columns = MAX(gridSize.columns, (unsigned short)4);
		gridSize.rows = MAX(gridSize.rows, (unsigned short)5);
	}

	return gridSize;
}

static BOOL ALEIsExpandedLibraryCategoryFolder(SBFolder *folder) {
	return [objc_getAssociatedObject(folder, &ALEExpandedLibraryCategoryFolderKey) boolValue];
}

static void ALEMarkExpandedLibraryCategoryFolder(SBFolder *folder) {
	if (folder) {
		objc_setAssociatedObject(folder, &ALEExpandedLibraryCategoryFolderKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}
}

static void ALEConfigureAppLibraryGrid(SBIconListGridLayoutConfiguration *configuration) {
	if (!configuration) {
		return;
	}

	BOOL rootLayout = ALEConfiguringLibraryRootLayout;
	CGSize screenSize = ALECurrentInterfaceSize();
	CGFloat landscapeWidth = MAX(screenSize.width, screenSize.height);
	CGFloat portraitWidth = MIN(screenSize.width, screenSize.height);
	CGSize spacingSize = ALEIsLandscapeScreen() ? CGSizeMake(landscapeWidth, portraitWidth) : CGSizeMake(portraitWidth, landscapeWidth);

	if ([configuration respondsToSelector:@selector(setNumberOfLandscapeColumns:)]) {
		configuration.numberOfLandscapeColumns = rootLayout ? 8 : 4;
	}
	if ([configuration respondsToSelector:@selector(setNumberOfLandscapeRows:)]) {
		configuration.numberOfLandscapeRows = rootLayout ? 8 : 4;
	}
	if ([configuration respondsToSelector:@selector(setNumberOfPortraitColumns:)]) {
		configuration.numberOfPortraitColumns = rootLayout ? 6 : 3;
	}
	if ([configuration respondsToSelector:@selector(setNumberOfPortraitRows:)]) {
		configuration.numberOfPortraitRows = rootLayout ? 10 : 5;
	}
	if ([configuration respondsToSelector:@selector(setListSizeForIconSpacingCalculation:)]) {
		configuration.listSizeForIconSpacingCalculation = spacingSize;
	}
	if ([configuration respondsToSelector:@selector(setLandscapeLayoutInsets:)]) {
		UIEdgeInsets insets = configuration.landscapeLayoutInsets;
		insets.left = rootLayout ? MAX((CGFloat)72.0, landscapeWidth * 0.075) : MAX((CGFloat)96.0, landscapeWidth * 0.11);
		insets.right = insets.left;
		configuration.landscapeLayoutInsets = insets;
	}
	if ([configuration respondsToSelector:@selector(setPortraitLayoutInsets:)]) {
		UIEdgeInsets insets = configuration.portraitLayoutInsets;
		insets.left = rootLayout ? MAX((CGFloat)48.0, portraitWidth * 0.08) : MAX((CGFloat)72.0, portraitWidth * 0.105);
		insets.right = insets.left;
		configuration.portraitLayoutInsets = insets;
	}
}

%hook SBIconController
- (bool)isAppLibraryAllowed {
	return YES;
}
- (bool)isAppLibrarySupported {
	return YES;
}
%end

%hook SBRootFolderView
- (bool)_shouldIgnoreOverscrollOnLastPageForCurrentOrientation {
	return YES;
}
- (bool)_shouldIgnoreOverscrollOnLastPageForOrientation:(NSInteger)orientation {
	return YES;
}
%end

%hook SBHIconManager
- (bool)rootFolder:(id)arg1 canAddIcon:(id)arg2 toIconList:(id)arg3 inFolder:(id)folder {
	bool origValue = %orig;
	if ( [folder isKindOfClass:%c( SBHLibraryCategoriesRootFolder )] ) {
		return YES;
	}
	return origValue;
}
%end

%hook SBHomeScreenOverlayViewController
-(CGFloat)contentWidth {
	if (ALEOverlayShowsAppLibrary(self)) {
		return ALEInterfaceWidthForView(self.view);
	}

	return %orig;
}
-(CGFloat)contentWidthWithContainerWidth:(CGFloat)containerWidth {
	if (ALEOverlayShowsAppLibrary(self)) {
		return containerWidth;
	}

	return %orig;
}
-(CGFloat)presentationProgress {
	CGFloat origValue = %orig;
	if (ALEOverlayShowsAppLibrary(self)) {
		NSLayoutConstraint *contentWidthConstraint = ALEValueForKey(self, @"contentWidthConstraint");
		if ([contentWidthConstraint isKindOfClass:[NSLayoutConstraint class]]) {
			contentWidthConstraint.constant = ALEInterfaceWidthForView(self.view);
		}
	}
	[[self rightSidebarViewController].view setAlpha:origValue];
	return origValue;
}
%end

%hook SBHDefaultIconListLayoutProvider
-(void)configureAppLibraryConfiguration:(SBIconListGridLayoutConfiguration *)configuration forScreenType:(unsigned long long)screenType layoutOptions:(unsigned long long)layoutOptions {
	%orig;
	ALEConfigureAppLibraryGrid(configuration);
}
-(id)makeLayoutForIconLocation:(id)iconLocation {
	BOOL previousRootLayout = ALEConfiguringLibraryRootLayout;
	ALEConfiguringLibraryRootLayout = ALEIsLibraryRootIconLocation(iconLocation);
	id layout = %orig;
	ALEConfiguringLibraryRootLayout = previousRootLayout;
	return layout;
}
-(id)layoutForIconLocation:(id)iconLocation {
	BOOL previousRootLayout = ALEConfiguringLibraryRootLayout;
	ALEConfiguringLibraryRootLayout = ALEIsLibraryRootIconLocation(iconLocation);
	id layout = %orig;
	ALEConfiguringLibraryRootLayout = previousRootLayout;
	return layout;
}
%end

%hook SBHLibraryCategory
-(SBHLibraryCategoryFolder *)expandedPodFolder {
	ALEBuildingExpandedLibraryCategoryFolderDepth++;
	SBHLibraryCategoryFolder *folder = nil;
	@try {
		folder = %orig;
	} @finally {
		ALEBuildingExpandedLibraryCategoryFolderDepth--;
	}
	ALEMarkExpandedLibraryCategoryFolder(folder);
	return folder;
}
%end

%hook SBHLibraryCategoryFolder
-(id)initWithDisplayName:(id)displayName maxListCount:(unsigned long long)maxListCount listGridSize:(struct SBHIconGridSize)listGridSize libraryCategoryIdentifier:(id)libraryCategoryIdentifier {
	BOOL buildingExpandedFolder = ALEBuildingExpandedLibraryCategoryFolderDepth > 0;
	if (buildingExpandedFolder) {
		listGridSize = ALEExpandedLibraryCategoryGridSize(listGridSize);
	}

	id folder = %orig(displayName, maxListCount, listGridSize, libraryCategoryIdentifier);
	if (buildingExpandedFolder) {
		ALEMarkExpandedLibraryCategoryFolder(folder);
	}
	return folder;
}
%end

%hook SBFolder
-(struct SBHIconGridSize)listGridSize {
	struct SBHIconGridSize gridSize = %orig;
	if (ALEIsLibraryCategoriesRootFolder(self)) {
		return ALELibraryRootGridSize(gridSize);
	}
	if (ALEIsExpandedLibraryCategoryFolder(self)) {
		return ALEExpandedLibraryCategoryGridSize(gridSize);
	}

	return gridSize;
}
%end

%hook SBIconListModel
-(struct SBHIconGridSize)gridSize {
	struct SBHIconGridSize gridSize = %orig;
	if (ALEIsLibraryCategoriesRootFolder(self.folder)) {
		return ALELibraryRootGridSize(gridSize);
	}
	if (ALEIsExpandedLibraryCategoryFolder(self.folder)) {
		return ALEExpandedLibraryCategoryGridSize(gridSize);
	}

	return gridSize;
}
-(id)gridCellInfoForGridSize:(struct SBHIconGridSize)gridSize options:(unsigned long long)options {
	if (ALEIsLibraryCategoriesRootFolder(self.folder)) {
		struct SBHIconGridSize rootGridSize = ALELibraryRootGridSize(gridSize);
		return %orig(rootGridSize, options);
	}
	if (ALEIsExpandedLibraryCategoryFolder(self.folder)) {
		struct SBHIconGridSize expandedGridSize = ALEExpandedLibraryCategoryGridSize(gridSize);
		return %orig(expandedGridSize, options);
	}

	return %orig;
}
%end

%hook SBHLibrarySearchController
- (void)viewDidAppear:(bool)arg1 {
	%orig;
	SBHSearchBar *searchBar = [self valueForKey:@"_searchBar"];
	UIView *containerView = [self valueForKey:@"_containerView"];
	UIView *contentContainerView = [self valueForKey:@"_contentContainerView"];
	UIView *searchResultsContainerView = [self valueForKey:@"_searchResultsContainerView"];

	CGRect selfFrame = self.view.frame;
	[containerView setFrame:selfFrame];
	[contentContainerView setFrame:selfFrame];
	[searchResultsContainerView setFrame:selfFrame];

	UIEdgeInsets searchTextFieldHorizontalEdgeInsets = [searchBar searchTextFieldHorizontalEdgeInsets];

	searchTextFieldHorizontalEdgeInsets.left = 23;
	searchTextFieldHorizontalEdgeInsets.right = 23;

	[searchBar setSearchTextFieldHorizontalEdgeInsets:searchTextFieldHorizontalEdgeInsets];
}
- (void)_layoutSearchViews {
	%orig;
	MTMaterialView *searchBackdropView = [self valueForKey:@"_searchBackdropView"];

	CGFloat width = [[UIScreen mainScreen] bounds].size.width;
	CGFloat height = [[UIScreen mainScreen] bounds].size.height;

	CGRect fullScreenFrame = CGRectMake(
		-100,
		-100,
		width + 200,
		height + 200
	);
	[searchBackdropView setBounds:fullScreenFrame];
	[searchBackdropView setFrame:fullScreenFrame];
}
%end

%hook SBHLibraryPodFolderController
- (void)viewDidAppear:(bool)arg1 {
	%orig;
	UIView *containerView = [self containerView];
	CGRect containerFrame = containerView.frame;
	[self.view setFrame:containerFrame];
}
%end

extern "C" bool _os_feature_enabled_impl(const char *domain, const char *feature);
%hookf(bool, _os_feature_enabled_impl, const char *domain, const char *feature) {
    if (strcmp(domain, "SpringBoard") == 0 && strcmp(feature, "Dewey") == 0)
        return true;
    return %orig;
}

%ctor {
	%init;
}
