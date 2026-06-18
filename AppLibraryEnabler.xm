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

@interface SBIconListModel : NSObject
@property (nonatomic, readonly) SBFolder *folder;
@property (nonatomic, readonly) unsigned long long numberOfIcons;
- (struct SBHIconGridSize)gridSize;
- (id)gridCellInfoForGridSize:(struct SBHIconGridSize)gridSize options:(unsigned long long)options;
@end

@interface SBIconListView : UIView
@property (nonatomic, readonly) SBIconListModel *model;
@property (nonatomic, readonly, copy) NSArray *icons;
@property (nonatomic) NSRange visibleColumnRange;
@property (nonatomic) NSRange visibleRowRange;
- (id)iconViewForIcon:(id)icon;
- (void)showAllIcons;
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
static BOOL ALELayingOutLibraryRootList = NO;
static BOOL ALEUpdatingLibraryRootVisibility = NO;

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

static CGFloat ALEFullWidthForView(UIView *view) {
	CGFloat width = 0;
	width = MAX(width, CGRectGetWidth(view.bounds));
	width = MAX(width, CGRectGetWidth(view.superview.bounds));
	width = MAX(width, CGRectGetWidth(view.window.bounds));
	width = MAX(width, [UIScreen mainScreen].bounds.size.width);
	width = MAX(width, [UIScreen mainScreen].bounds.size.height);
	return width;
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

static BOOL ALEIsLandscapeScreen(void) {
	NSNumber *orientationValue = ALEValueForKey([UIApplication sharedApplication], @"statusBarOrientation");
	if ([orientationValue isKindOfClass:[NSNumber class]]) {
		UIInterfaceOrientation orientation = (UIInterfaceOrientation)[orientationValue integerValue];
		return UIInterfaceOrientationIsLandscape(orientation);
	}

	CGSize screenSize = [UIScreen mainScreen].bounds.size;
	return screenSize.width > screenSize.height;
}

static BOOL ALEIsLandscapeForView(UIView *view) {
	if ([view isKindOfClass:[UIView class]]) {
		CGSize windowSize = view.window.bounds.size;
		if (windowSize.width > 0 && windowSize.height > 0 && fabs(windowSize.width - windowSize.height) > 1.0) {
			return windowSize.width > windowSize.height;
		}

		CGSize boundsSize = view.bounds.size;
		if (boundsSize.width > 0 && boundsSize.height > 0 && fabs(boundsSize.width - boundsSize.height) > 1.0) {
			return boundsSize.width > boundsSize.height;
		}
	}

	return ALEIsLandscapeScreen();
}

static unsigned long long ALELibraryRootPodColumnsForLandscape(BOOL landscape) {
	return landscape ? 4 : 3;
}

static unsigned long long ALELibraryRootPodColumns(void) {
	return ALELibraryRootPodColumnsForLandscape(ALEIsLandscapeScreen());
}

static struct SBHIconGridSize ALELibraryRootGridSize(struct SBHIconGridSize originalGridSize, unsigned long long iconCount) {
	struct SBHIconGridSize gridSize = originalGridSize;
	unsigned long long podColumns = ALELibraryRootPodColumns();
	unsigned long long podRows = iconCount > 0 ? ((iconCount + podColumns - 1) / podColumns) : (ALEIsLandscapeScreen() ? 4 : 5);

	gridSize.columns = MAX(gridSize.columns, (unsigned short)(podColumns * 2));
	gridSize.rows = MAX(gridSize.rows, (unsigned short)(podRows * 2));
	return gridSize;
}

static unsigned long long ALELibraryRootGridCellIndexForIconIndex(NSUInteger iconIndex, struct SBHIconGridSize gridSize) {
	unsigned long long podColumns = MAX((unsigned long long)1, (unsigned long long)gridSize.columns / 2);
	unsigned long long row = iconIndex / podColumns;
	unsigned long long column = iconIndex % podColumns;
	return (row * 2 * gridSize.columns) + (column * 2);
}

static void ALEReflowLibraryRootGridCellInfo(SBIconListGridCellInfo *gridCellInfo, NSUInteger iconCount, struct SBHIconGridSize gridSize) {
	if (!gridCellInfo || iconCount == 0 || gridSize.columns == 0) {
		return;
	}

	[gridCellInfo clearAllIconAndGridCellIndexes];
	gridCellInfo.gridSize = gridSize;

	for (NSUInteger iconIndex = 0; iconIndex < iconCount; iconIndex++) {
		unsigned long long gridCellIndex = ALELibraryRootGridCellIndexForIconIndex(iconIndex, gridSize);
		[gridCellInfo setGridCellIndex:gridCellIndex forIconIndex:iconIndex];
		[gridCellInfo setIconIndex:iconIndex forGridCellIndex:gridCellIndex];
		[gridCellInfo setIconIndex:iconIndex forGridCellIndex:gridCellIndex + 1];
		[gridCellInfo setIconIndex:iconIndex forGridCellIndex:gridCellIndex + gridSize.columns];
		[gridCellInfo setIconIndex:iconIndex forGridCellIndex:gridCellIndex + gridSize.columns + 1];
	}

	unsigned long long podColumns = MAX((unsigned long long)1, (unsigned long long)gridSize.columns / 2);
	unsigned long long podRows = (iconCount + podColumns - 1) / podColumns;
	gridCellInfo.numberOfUsedColumns = MIN((unsigned long long)gridSize.columns, podColumns * 2);
	gridCellInfo.numberOfUsedRows = MAX((unsigned long long)1, podRows * 2);
}

static BOOL ALEIsLibraryRootListView(SBIconListView *listView) {
	if (!listView || ![listView respondsToSelector:@selector(model)]) {
		return NO;
	}

	SBIconListModel *model = listView.model;
	if (!model || ![model respondsToSelector:@selector(folder)]) {
		return NO;
	}

	return ALEIsLibraryCategoriesRootFolder(model.folder);
}

static void ALEExposeLibraryRootVisibleRange(SBIconListView *listView, NSUInteger columnCount, NSUInteger rowCount) {
	if (ALEUpdatingLibraryRootVisibility || !ALEIsLibraryRootListView(listView) || columnCount == 0 || rowCount == 0) {
		return;
	}

	ALEUpdatingLibraryRootVisibility = YES;
	@try {
		NSRange visibleColumnRange = NSMakeRange(0, columnCount * 2);
		NSRange visibleRowRange = NSMakeRange(0, rowCount * 2);

		if ([listView respondsToSelector:@selector(setVisibleColumnRange:)]) {
			listView.visibleColumnRange = visibleColumnRange;
		}
		if ([listView respondsToSelector:@selector(setVisibleRowRange:)]) {
			listView.visibleRowRange = visibleRowRange;
		}
		if ([listView respondsToSelector:@selector(showAllIcons)]) {
			[listView showAllIcons];
		}
	} @finally {
		ALEUpdatingLibraryRootVisibility = NO;
	}
}

static void ALELayoutLibraryRootListView(SBIconListView *listView) {
	if (ALELayingOutLibraryRootList || !ALEIsLibraryRootListView(listView) || ![listView respondsToSelector:@selector(icons)] || ![listView respondsToSelector:@selector(iconViewForIcon:)]) {
		return;
	}

	NSArray *icons = listView.icons;
	if (![icons isKindOfClass:[NSArray class]] || icons.count == 0) {
		return;
	}

	CGFloat listWidth = CGRectGetWidth(listView.bounds);
	if (listWidth <= 0) {
		listWidth = CGRectGetWidth(listView.superview.bounds);
	}
	if (listWidth <= 0) {
		listWidth = ALEFullWidthForView(listView);
	}

	BOOL landscape = ALEIsLandscapeForView(listView);
	NSUInteger columnCount = ALELibraryRootPodColumnsForLandscape(landscape);
	NSUInteger rowCount = ((NSUInteger)icons.count + columnCount - 1) / columnCount;
	ALEExposeLibraryRootVisibleRange(listView, columnCount, rowCount);

	CGFloat topY = CGFLOAT_MAX;
	CGFloat secondY = CGFLOAT_MAX;
	CGFloat podWidth = 0;
	CGFloat podHeight = 0;

	for (id icon in icons) {
		UIView *iconView = [listView iconViewForIcon:icon];
		if (![iconView isKindOfClass:[UIView class]] || iconView.hidden) {
			continue;
		}

		CGRect frame = iconView.frame;
		if (CGRectGetWidth(frame) <= 0 || CGRectGetHeight(frame) <= 0) {
			continue;
		}

		podWidth = MAX(podWidth, CGRectGetWidth(frame));
		podHeight = MAX(podHeight, CGRectGetHeight(frame));

		CGFloat y = CGRectGetMinY(frame);
		if (y < topY - 1.0) {
			secondY = topY;
			topY = y;
		} else if (y > topY + 8.0 && y < secondY - 1.0) {
			secondY = y;
		}
	}

	if (podWidth <= 0 || podHeight <= 0 || topY == CGFLOAT_MAX) {
		return;
	}

	CGFloat horizontalInset = landscape ? MAX((CGFloat)122.0, listWidth * 0.075) : MAX((CGFloat)72.0, listWidth * 0.085);
	CGFloat availableWidth = listWidth - (horizontalInset * 2.0);
	if (availableWidth < (podWidth * columnCount)) {
		horizontalInset = 36.0;
		availableWidth = listWidth - (horizontalInset * 2.0);
	}

	CGFloat columnGap = columnCount > 1 ? (availableWidth - (podWidth * columnCount)) / (CGFloat)(columnCount - 1) : 0;
	if (columnGap < 24.0) {
		columnGap = 24.0;
	}

	CGFloat rowStep = secondY != CGFLOAT_MAX ? secondY - topY : podHeight + 44.0;
	if (rowStep < podHeight + 28.0) {
		rowStep = podHeight + 36.0;
	}

	ALELayingOutLibraryRootList = YES;
	for (NSUInteger iconIndex = 0; iconIndex < icons.count; iconIndex++) {
		UIView *iconView = [listView iconViewForIcon:[icons objectAtIndex:iconIndex]];
		if (![iconView isKindOfClass:[UIView class]] || iconView.hidden) {
			continue;
		}

		NSUInteger column = iconIndex % columnCount;
		NSUInteger row = iconIndex / columnCount;
		CGRect frame = iconView.frame;
		frame.origin.x = horizontalInset + ((podWidth + columnGap) * column);
		frame.origin.y = topY + (rowStep * row);
		iconView.frame = frame;
	}
	ALELayingOutLibraryRootList = NO;
}

static void ALEConfigureAppLibraryGrid(SBIconListGridLayoutConfiguration *configuration) {
	if (!configuration) {
		return;
	}

	BOOL rootLayout = ALEConfiguringLibraryRootLayout;
	CGSize screenSize = [UIScreen mainScreen].bounds.size;
	CGFloat landscapeWidth = MAX(screenSize.width, screenSize.height);
	CGFloat portraitWidth = MIN(screenSize.width, screenSize.height);
	CGSize spacingSize = CGSizeMake(landscapeWidth, portraitWidth);

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
		return ALEFullWidthForView(self.view);
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
			contentWidthConstraint.constant = ALEFullWidthForView(self.view);
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

%hook SBFolder
-(struct SBHIconGridSize)listGridSize {
	struct SBHIconGridSize gridSize = %orig;
	if (ALEIsLibraryCategoriesRootFolder(self)) {
		return ALELibraryRootGridSize(gridSize, 0);
	}

	return gridSize;
}
%end

%hook SBIconListModel
-(struct SBHIconGridSize)gridSize {
	struct SBHIconGridSize gridSize = %orig;
	if (ALEIsLibraryCategoriesRootFolder(self.folder)) {
		return ALELibraryRootGridSize(gridSize, self.numberOfIcons);
	}

	return gridSize;
}
-(id)gridCellInfoForGridSize:(struct SBHIconGridSize)gridSize options:(unsigned long long)options {
	id gridCellInfo = %orig;
	if (ALEIsLibraryCategoriesRootFolder(self.folder)) {
		struct SBHIconGridSize rootGridSize = ALELibraryRootGridSize(gridSize, self.numberOfIcons);
		ALEReflowLibraryRootGridCellInfo((SBIconListGridCellInfo *)gridCellInfo, self.numberOfIcons, rootGridSize);
	}

	return gridCellInfo;
}
%end

%hook SBIconListView
- (void)layoutSubviews {
	%orig;
	ALELayoutLibraryRootListView(self);
}
- (void)layoutIconsNow {
	%orig;
	ALELayoutLibraryRootListView(self);
}
- (void)layoutIconsIfNeeded {
	%orig;
	ALELayoutLibraryRootListView(self);
}
- (void)layoutIconsIfNeeded:(double)arg1 {
	%orig;
	ALELayoutLibraryRootListView(self);
}
- (void)layoutIconsIfNeededUsingAnimator:(id)arg1 options:(unsigned long long)arg2 {
	%orig;
	ALELayoutLibraryRootListView(self);
}
- (void)layoutIconsIfNeeded:(double)arg1 animationType:(long long)arg2 options:(unsigned long long)arg3 {
	%orig;
	ALELayoutLibraryRootListView(self);
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
