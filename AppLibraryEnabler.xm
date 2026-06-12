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

@interface SBHLibraryPodFolderController (AppLibraryEnabler)
+ (id)iconLocation;
@end

@interface SBIconListGridLayoutConfiguration : NSObject
@property (nonatomic) unsigned long long numberOfLandscapeColumns;
@property (nonatomic) unsigned long long numberOfLandscapeRows;
@property (nonatomic) unsigned long long numberOfPortraitColumns;
@property (nonatomic) unsigned long long numberOfPortraitRows;
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

@interface SBHLibraryCategoryFolder : SBFolder
- (id)initWithDisplayName:(id)displayName maxListCount:(unsigned long long)maxListCount listGridSize:(struct SBHIconGridSize)listGridSize libraryCategoryIdentifier:(id)libraryCategoryIdentifier;
@end

@interface SBIconListModel : NSObject
@property (nonatomic, readonly) SBFolder *folder;
@property (nonatomic, readonly) unsigned long long numberOfIcons;
- (struct SBHIconGridSize)gridSize;
- (id)gridCellInfoForGridSize:(struct SBHIconGridSize)gridSize options:(unsigned long long)options;
@end

@interface SBIconListView : UIView
@property (nonatomic, readonly) SBIconListModel *model;
- (struct SBHIconGridSize)gridSizeForCurrentOrientation;
- (unsigned long long)iconColumnsForCurrentOrientation;
- (unsigned long long)iconRowsForCurrentOrientation;
- (unsigned long long)iconsInRowForSpacingCalculation;
- (unsigned long long)iconRowsForSpacingCalculation;
@end

@interface SBIconListGridCellInfo : NSObject
@property (nonatomic) struct SBHIconGridSize gridSize;
@property (nonatomic) unsigned long long numberOfUsedColumns;
@property (nonatomic) unsigned long long numberOfUsedRows;
- (void)clearAllIconAndGridCellIndexes;
- (void)setGridCellIndex:(unsigned long long)gridCellIndex forIconIndex:(unsigned long long)iconIndex;
- (void)setIconIndex:(unsigned long long)iconIndex forGridCellIndex:(unsigned long long)gridCellIndex;
@end

static BOOL ALEConfiguringLibraryRootLayout = NO;

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

static void ALEConfigureAppLibraryGrid(SBIconListGridLayoutConfiguration *configuration, BOOL libraryRootLayout) {
	if (!configuration) {
		return;
	}

	CGSize screenSize = [UIScreen mainScreen].bounds.size;
	CGFloat width = MAX(screenSize.width, screenSize.height);
	CGFloat height = MIN(screenSize.width, screenSize.height);

	if ([configuration respondsToSelector:@selector(setNumberOfLandscapeColumns:)]) {
		configuration.numberOfLandscapeColumns = libraryRootLayout ? 8 : 4;
	}
	if (libraryRootLayout && [configuration respondsToSelector:@selector(setNumberOfLandscapeRows:)]) {
		configuration.numberOfLandscapeRows = 4;
	}
	if ([configuration respondsToSelector:@selector(setNumberOfPortraitColumns:)]) {
		configuration.numberOfPortraitColumns = libraryRootLayout ? 6 : 3;
	}
	if (libraryRootLayout && [configuration respondsToSelector:@selector(setNumberOfPortraitRows:)]) {
		configuration.numberOfPortraitRows = 6;
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

static BOOL ALEIsLibraryCategoriesRootFolder(SBFolder *folder) {
	return ALEObjectIsKindOfClassNamed(folder, @"SBHLibraryCategoriesRootFolder");
}

static struct SBHIconGridSize ALELibraryCategoriesRootGridSize(struct SBHIconGridSize originalGridSize) {
	struct SBHIconGridSize gridSize = originalGridSize;

	if (ALEIsLandscapeScreen()) {
		gridSize.columns = MAX(gridSize.columns, 8);
		gridSize.rows = MAX(gridSize.rows, 4);
	} else {
		gridSize.columns = MAX(gridSize.columns, 6);
		gridSize.rows = MAX(gridSize.rows, 6);
	}

	return gridSize;
}

static unsigned long long ALELibraryCategoriesRootPodColumnsForGridSize(struct SBHIconGridSize gridSize) {
	return MAX((unsigned long long)1, (unsigned long long)gridSize.columns / 2);
}

static unsigned long long ALELibraryCategoriesRootUsedRowsForIconCount(NSUInteger iconCount, struct SBHIconGridSize gridSize) {
	if (iconCount == 0) {
		return 0;
	}

	unsigned long long podColumns = ALELibraryCategoriesRootPodColumnsForGridSize(gridSize);
	unsigned long long podRows = ((unsigned long long)iconCount + podColumns - 1) / podColumns;
	return MAX((unsigned long long)1, podRows * 2);
}

static unsigned long long ALELibraryCategoriesRootGridCellIndexForIconIndex(NSUInteger iconIndex, struct SBHIconGridSize gridSize) {
	unsigned long long podColumns = ALELibraryCategoriesRootPodColumnsForGridSize(gridSize);
	unsigned long long row = iconIndex / podColumns;
	unsigned long long column = iconIndex % podColumns;
	return (row * 2 * gridSize.columns) + (column * 2);
}

static void ALEReflowLibraryCategoriesRootGridCellInfo(SBIconListGridCellInfo *gridCellInfo, NSUInteger iconCount, struct SBHIconGridSize gridSize) {
	if (!gridCellInfo || iconCount == 0 || gridSize.columns == 0) {
		return;
	}

	gridCellInfo.gridSize = gridSize;
	[gridCellInfo clearAllIconAndGridCellIndexes];

	for (NSUInteger iconIndex = 0; iconIndex < iconCount; iconIndex++) {
		unsigned long long gridCellIndex = ALELibraryCategoriesRootGridCellIndexForIconIndex(iconIndex, gridSize);
		[gridCellInfo setGridCellIndex:gridCellIndex forIconIndex:iconIndex];
		[gridCellInfo setIconIndex:iconIndex forGridCellIndex:gridCellIndex];
		[gridCellInfo setIconIndex:iconIndex forGridCellIndex:gridCellIndex + 1];
		[gridCellInfo setIconIndex:iconIndex forGridCellIndex:gridCellIndex + gridSize.columns];
		[gridCellInfo setIconIndex:iconIndex forGridCellIndex:gridCellIndex + gridSize.columns + 1];
	}

	unsigned long long podColumns = ALELibraryCategoriesRootPodColumnsForGridSize(gridSize);
	gridCellInfo.numberOfUsedColumns = MIN((unsigned long long)gridSize.columns, podColumns * 2);
	gridCellInfo.numberOfUsedRows = ALELibraryCategoriesRootUsedRowsForIconCount(iconCount, gridSize);
}

static BOOL ALEIsLibraryCategoriesRootListView(SBIconListView *listView) {
	if (!listView || ![listView respondsToSelector:@selector(model)]) {
		return NO;
	}

	SBIconListModel *model = listView.model;
	if (!model || ![model respondsToSelector:@selector(folder)]) {
		return NO;
	}

	return ALEIsLibraryCategoriesRootFolder(model.folder);
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
	ALEConfigureAppLibraryGrid(configuration, ALEConfiguringLibraryRootLayout);
}
- (id)makeLayoutForIconLocation:(id)iconLocation {
	BOOL previousConfiguringLibraryRootLayout = ALEConfiguringLibraryRootLayout;
	ALEConfiguringLibraryRootLayout = ALEIsLibraryRootIconLocation(iconLocation);
	id layout = %orig;
	ALEConfiguringLibraryRootLayout = previousConfiguringLibraryRootLayout;
	return layout;
}
- (id)layoutForIconLocation:(id)iconLocation {
	BOOL previousConfiguringLibraryRootLayout = ALEConfiguringLibraryRootLayout;
	ALEConfiguringLibraryRootLayout = ALEIsLibraryRootIconLocation(iconLocation);
	id layout = %orig;
	ALEConfiguringLibraryRootLayout = previousConfiguringLibraryRootLayout;
	return layout;
}
%end

%hook SBFolder
- (struct SBHIconGridSize)listGridSize {
	struct SBHIconGridSize gridSize = %orig;
	if (ALEIsLibraryCategoriesRootFolder(self)) {
		return ALELibraryCategoriesRootGridSize(gridSize);
	}

	return gridSize;
}
%end

%hook SBIconListModel
- (struct SBHIconGridSize)gridSize {
	struct SBHIconGridSize gridSize = %orig;
	if (ALEIsLibraryCategoriesRootFolder(self.folder)) {
		return ALELibraryCategoriesRootGridSize(gridSize);
	}

	return gridSize;
}
- (id)gridCellInfoForGridSize:(struct SBHIconGridSize)gridSize options:(unsigned long long)options {
	id gridCellInfo = %orig;
	if (ALEIsLibraryCategoriesRootFolder(self.folder)) {
		struct SBHIconGridSize rootGridSize = ALELibraryCategoriesRootGridSize(gridSize);
		ALEReflowLibraryCategoriesRootGridCellInfo((SBIconListGridCellInfo *)gridCellInfo, self.numberOfIcons, rootGridSize);
	}

	return gridCellInfo;
}
- (unsigned long long)numberOfUsedColumns {
	unsigned long long usedColumns = %orig;
	if (ALEIsLibraryCategoriesRootFolder(self.folder)) {
		struct SBHIconGridSize rootGridSize = ALELibraryCategoriesRootGridSize(self.gridSize);
		return MAX(usedColumns, (unsigned long long)rootGridSize.columns);
	}

	return usedColumns;
}
- (unsigned long long)numberOfUsedRows {
	unsigned long long usedRows = %orig;
	if (ALEIsLibraryCategoriesRootFolder(self.folder)) {
		struct SBHIconGridSize rootGridSize = ALELibraryCategoriesRootGridSize(self.gridSize);
		return MAX(usedRows, ALELibraryCategoriesRootUsedRowsForIconCount(self.numberOfIcons, rootGridSize));
	}

	return usedRows;
}
%end

%hook SBIconListView
- (struct SBHIconGridSize)gridSizeForCurrentOrientation {
	struct SBHIconGridSize gridSize = %orig;
	if (ALEIsLibraryCategoriesRootListView(self)) {
		return ALELibraryCategoriesRootGridSize(gridSize);
	}

	return gridSize;
}
- (unsigned long long)iconColumnsForCurrentOrientation {
	unsigned long long columns = %orig;
	if (ALEIsLibraryCategoriesRootListView(self)) {
		struct SBHIconGridSize gridSize = { (unsigned short)columns, 0 };
		return ALELibraryCategoriesRootGridSize(gridSize).columns;
	}

	return columns;
}
- (unsigned long long)iconRowsForCurrentOrientation {
	unsigned long long rows = %orig;
	if (ALEIsLibraryCategoriesRootListView(self)) {
		struct SBHIconGridSize gridSize = { 0, (unsigned short)rows };
		return ALELibraryCategoriesRootGridSize(gridSize).rows;
	}

	return rows;
}
- (unsigned long long)iconsInRowForSpacingCalculation {
	unsigned long long iconsInRow = %orig;
	if (ALEIsLibraryCategoriesRootListView(self)) {
		struct SBHIconGridSize gridSize = { (unsigned short)iconsInRow, 0 };
		return ALELibraryCategoriesRootGridSize(gridSize).columns;
	}

	return iconsInRow;
}
- (unsigned long long)iconRowsForSpacingCalculation {
	unsigned long long rows = %orig;
	if (ALEIsLibraryCategoriesRootListView(self)) {
		struct SBHIconGridSize gridSize = { 0, (unsigned short)rows };
		return ALELibraryCategoriesRootGridSize(gridSize).rows;
	}

	return rows;
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
