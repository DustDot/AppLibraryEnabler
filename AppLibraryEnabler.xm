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

@interface SBIconListGridLayoutConfiguration : NSObject
@property (nonatomic) unsigned long long numberOfLandscapeColumns;
@property (nonatomic) unsigned long long numberOfPortraitColumns;
@property (nonatomic) CGSize listSizeForIconSpacingCalculation;
@property (nonatomic) UIEdgeInsets landscapeLayoutInsets;
@property (nonatomic) UIEdgeInsets portraitLayoutInsets;
@end

struct SBHIconGridSize {
	unsigned short columns;
	unsigned short rows;
};

@interface SBFolder : NSObject
- (struct SBHIconGridSize)listGridSize;
@end

@interface SBHLibraryCategoriesRootFolder : SBFolder
@end

@interface SBHLibraryCategoryFolder : SBFolder
- (id)initWithDisplayName:(id)displayName maxListCount:(unsigned long long)maxListCount listGridSize:(struct SBHIconGridSize)listGridSize libraryCategoryIdentifier:(id)libraryCategoryIdentifier;
@end

@interface SBHLibraryCategory : NSObject
- (SBHLibraryCategoryFolder *)expandedPodFolder;
@end

@interface SBIconListModel : NSObject
@property (nonatomic, readonly) SBFolder *folder;
- (struct SBHIconGridSize)gridSize;
@end

@interface SBHLibraryPodFolderView : UIView
- (void)setFolder:(SBFolder *)folder;
- (CGSize)_iconListViewSize;
- (double)_pageWidth;
- (CGRect)_iconListFrameForPageRect:(CGRect)pageRect atIndex:(unsigned long long)index;
- (CGRect)_frameForIconListAtIndex:(unsigned long long)index;
@end

static char ALEExpandedLibraryCategoryFolderKey;
static char ALEWideLibraryPodFolderViewKey;
static NSUInteger ALEBuildingExpandedLibraryCategoryFolderDepth;

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

static CGFloat ALEFullWidthForView(UIView *view) {
	CGFloat width = 0;
	width = MAX(width, CGRectGetWidth(view.bounds));
	width = MAX(width, CGRectGetWidth(view.superview.bounds));
	width = MAX(width, CGRectGetWidth(view.window.bounds));

	CGSize screenSize = [UIScreen mainScreen].bounds.size;
	width = MAX(width, screenSize.width);

	return width;
}

static BOOL ALEOverlayShowsAppLibrary(SBHomeScreenOverlayViewController *overlayController) {
	id rightSidebarViewController = ALEValueForKey(overlayController, @"rightSidebarViewController");
	id contentViewController = ALEValueForKey(overlayController, @"contentViewController");

	return ALEIsLibraryController(rightSidebarViewController) || ALEIsLibraryController(contentViewController);
}

static void ALEUpdateOverlayLayout(SBHomeScreenOverlayViewController *overlayController) {
	if (!overlayController || !ALEOverlayShowsAppLibrary(overlayController)) {
		return;
	}

	CGFloat fullWidth = ALEFullWidthForView(overlayController.view);
	NSLayoutConstraint *contentWidthConstraint = ALEValueForKey(overlayController, @"contentWidthConstraint");
	if ([contentWidthConstraint isKindOfClass:[NSLayoutConstraint class]]) {
		contentWidthConstraint.constant = fullWidth;
	}
}

static void ALELayoutLibrarySearchController(SBHLibrarySearchController *searchController) {
	if (!searchController.view) {
		return;
	}

	SBHSearchBar *searchBar = ALEValueForKey(searchController, @"_searchBar");
	UIView *containerView = ALEValueForKey(searchController, @"_containerView");
	UIView *contentContainerView = ALEValueForKey(searchController, @"_contentContainerView");
	UIView *searchResultsContainerView = ALEValueForKey(searchController, @"_searchResultsContainerView");

	CGRect fullFrame = searchController.view.bounds;
	[containerView setFrame:fullFrame];
	[contentContainerView setFrame:fullFrame];
	[searchResultsContainerView setFrame:fullFrame];

	if ([searchBar respondsToSelector:@selector(searchTextFieldHorizontalEdgeInsets)] && [searchBar respondsToSelector:@selector(setSearchTextFieldHorizontalEdgeInsets:)]) {
		UIEdgeInsets searchTextFieldHorizontalEdgeInsets = [searchBar searchTextFieldHorizontalEdgeInsets];
		searchTextFieldHorizontalEdgeInsets.left = 23;
		searchTextFieldHorizontalEdgeInsets.right = 23;
		[searchBar setSearchTextFieldHorizontalEdgeInsets:searchTextFieldHorizontalEdgeInsets];
	}
}

static void ALEConfigureAppLibraryGrid(SBIconListGridLayoutConfiguration *configuration) {
	if (!configuration) {
		return;
	}

	CGSize screenSize = [UIScreen mainScreen].bounds.size;
	CGFloat width = MAX(screenSize.width, screenSize.height);
	CGFloat height = MIN(screenSize.width, screenSize.height);

	if ([configuration respondsToSelector:@selector(setNumberOfLandscapeColumns:)]) {
		configuration.numberOfLandscapeColumns = 4;
	}
	if ([configuration respondsToSelector:@selector(setNumberOfPortraitColumns:)]) {
		configuration.numberOfPortraitColumns = 3;
	}
	if ([configuration respondsToSelector:@selector(setListSizeForIconSpacingCalculation:)]) {
		configuration.listSizeForIconSpacingCalculation = CGSizeMake(width, height);
	}
	if ([configuration respondsToSelector:@selector(setLandscapeLayoutInsets:)]) {
		UIEdgeInsets insets = configuration.landscapeLayoutInsets;
		insets.left = 72;
		insets.right = 72;
		configuration.landscapeLayoutInsets = insets;
	}
	if ([configuration respondsToSelector:@selector(setPortraitLayoutInsets:)]) {
		UIEdgeInsets insets = configuration.portraitLayoutInsets;
		insets.left = 48;
		insets.right = 48;
		configuration.portraitLayoutInsets = insets;
	}
}

static BOOL ALEIsLandscapeScreen(void) {
	CGSize screenSize = [UIScreen mainScreen].bounds.size;
	return screenSize.width > screenSize.height;
}

static struct SBHIconGridSize ALEExpandedLibraryCategoryGridSize(struct SBHIconGridSize originalGridSize) {
	struct SBHIconGridSize gridSize = originalGridSize;

	if (ALEIsLandscapeScreen()) {
		gridSize.columns = MAX(gridSize.columns, 6);
		gridSize.rows = MAX(gridSize.rows, 4);
	} else {
		gridSize.columns = MAX(gridSize.columns, 4);
		gridSize.rows = MAX(gridSize.rows, 5);
	}

	return gridSize;
}

static BOOL ALEIsLibraryCategoriesRootFolder(SBFolder *folder) {
	return ALEObjectIsKindOfClassNamed(folder, @"SBHLibraryCategoriesRootFolder");
}

static BOOL ALEIsExpandedLibraryCategoryFolder(SBFolder *folder);

static BOOL ALEShouldUseWideLibraryPodFolderViewForFolder(SBFolder *folder) {
	return ALEIsLibraryCategoriesRootFolder(folder) || ALEIsExpandedLibraryCategoryFolder(folder);
}

static BOOL ALEIsWideLibraryPodFolderView(SBHLibraryPodFolderView *folderView) {
	return [objc_getAssociatedObject(folderView, &ALEWideLibraryPodFolderViewKey) boolValue];
}

static CGFloat ALELibraryVisualWidthForView(UIView *view) {
	CGFloat width = ALEFullWidthForView(view);
	CGSize screenSize = [UIScreen mainScreen].bounds.size;
	width = MAX(width, MAX(screenSize.width, screenSize.height));
	return width;
}

static CGRect ALECenteredFullWidthFrameForFolderView(SBHLibraryPodFolderView *folderView, CGRect originalFrame) {
	CGFloat fullWidth = ALELibraryVisualWidthForView(folderView);
	if (fullWidth <= CGRectGetWidth(originalFrame)) {
		return originalFrame;
	}

	CGRect frame = originalFrame;
	frame.size.width = fullWidth;
	frame.origin.x = floor((CGRectGetWidth(folderView.bounds) - fullWidth) / 2.0);
	return frame;
}

static BOOL ALEIsExpandedLibraryCategoryFolder(SBFolder *folder) {
	return [objc_getAssociatedObject(folder, &ALEExpandedLibraryCategoryFolderKey) boolValue];
}

static void ALEMarkExpandedLibraryCategoryFolder(SBFolder *folder) {
	if (folder) {
		objc_setAssociatedObject(folder, &ALEExpandedLibraryCategoryFolderKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
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

%hook SBHDefaultIconListLayoutProvider
- (void)configureAppLibraryConfiguration:(SBIconListGridLayoutConfiguration *)configuration forScreenType:(unsigned long long)screenType layoutOptions:(unsigned long long)layoutOptions {
	%orig;
	ALEConfigureAppLibraryGrid(configuration);
}
%end

%hook SBHLibraryCategory
- (SBHLibraryCategoryFolder *)expandedPodFolder {
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
- (id)initWithDisplayName:(id)displayName maxListCount:(unsigned long long)maxListCount listGridSize:(struct SBHIconGridSize)listGridSize libraryCategoryIdentifier:(id)libraryCategoryIdentifier {
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
- (struct SBHIconGridSize)listGridSize {
	struct SBHIconGridSize gridSize = %orig;
	if (ALEIsExpandedLibraryCategoryFolder(self)) {
		return ALEExpandedLibraryCategoryGridSize(gridSize);
	}

	return gridSize;
}
%end

%hook SBIconListModel
- (struct SBHIconGridSize)gridSize {
	struct SBHIconGridSize gridSize = %orig;
	if (ALEIsExpandedLibraryCategoryFolder(self.folder)) {
		return ALEExpandedLibraryCategoryGridSize(gridSize);
	}

	return gridSize;
}
%end

%hook SBHLibraryPodFolderView
- (void)setFolder:(SBFolder *)folder {
	%orig;
	if (ALEShouldUseWideLibraryPodFolderViewForFolder(folder)) {
		objc_setAssociatedObject(self, &ALEWideLibraryPodFolderViewKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	} else {
		objc_setAssociatedObject(self, &ALEWideLibraryPodFolderViewKey, nil, OBJC_ASSOCIATION_ASSIGN);
	}
}
- (CGSize)_iconListViewSize {
	CGSize size = %orig;
	if (ALEIsWideLibraryPodFolderView(self)) {
		size.width = MAX(size.width, ALELibraryVisualWidthForView(self));
	}
	return size;
}
- (double)_pageWidth {
	double width = %orig;
	if (ALEIsWideLibraryPodFolderView(self)) {
		width = MAX(width, ALELibraryVisualWidthForView(self));
	}
	return width;
}
- (CGRect)_iconListFrameForPageRect:(CGRect)pageRect atIndex:(unsigned long long)index {
	CGRect frame = %orig;
	if (ALEIsWideLibraryPodFolderView(self)) {
		frame = ALECenteredFullWidthFrameForFolderView(self, frame);
	}
	return frame;
}
- (CGRect)_frameForIconListAtIndex:(unsigned long long)index {
	CGRect frame = %orig;
	if (ALEIsWideLibraryPodFolderView(self)) {
		frame = ALECenteredFullWidthFrameForFolderView(self, frame);
	}
	return frame;
}
%end

%hook SBHomeScreenOverlayViewController
- (CGFloat)contentWidth {
	if (ALEOverlayShowsAppLibrary(self)) {
		return ALEFullWidthForView(self.view);
	}

	return %orig;
}
- (CGFloat)contentWidthWithContainerWidth:(CGFloat)containerWidth {
	if (ALEOverlayShowsAppLibrary(self)) {
		return containerWidth;
	}

	return %orig;
}
-(CGFloat)presentationProgress {
	CGFloat origValue = %orig;
	ALEUpdateOverlayLayout(self);
	[[self rightSidebarViewController].view setAlpha:origValue];
	return origValue;
}
- (void)viewDidLayoutSubviews {
	%orig;
	ALEUpdateOverlayLayout(self);
}
- (void)viewWillLayoutSubviews {
	%orig;
	ALEUpdateOverlayLayout(self);
}
%end

%hook SBHLibrarySearchController
- (void)viewDidLoad {
	%orig;
	ALELayoutLibrarySearchController(self);
}
- (void)viewWillAppear:(bool)arg1 {
	%orig;
	ALELayoutLibrarySearchController(self);
}
- (void)viewDidAppear:(bool)arg1 {
	%orig;
	ALELayoutLibrarySearchController(self);
}
- (void)viewWillLayoutSubviews {
	%orig;
	ALELayoutLibrarySearchController(self);
}
- (void)_layoutSearchViews {
	%orig;
	ALELayoutLibrarySearchController(self);
	MTMaterialView *searchBackdropView = ALEValueForKey(self, @"_searchBackdropView");

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
	if (strcmp(domain, "SpringBoard") == 0 && strcmp(feature, "Dewey") == 0) {
		return true;
	}
	return %orig;
}

%ctor {
	%init;
}
