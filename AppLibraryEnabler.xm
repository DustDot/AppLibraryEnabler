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
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <math.h>

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
- (void)ale_refreshLibrarySearchDuringFolderAnimation;
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
@property (nonatomic, readonly, copy) NSArray *icons;
@property (nonatomic) NSRange visibleColumnRange;
@property (nonatomic) NSRange visibleRowRange;
- (id)iconViewForIcon:(id)icon;
- (void)setFrame:(CGRect)frame;
- (void)setBounds:(CGRect)bounds;
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
static BOOL ALEUpdatingLibraryRootScrollRange = NO;
static BOOL ALEUpdatingLibraryRootVisibility = NO;
static CGRect ALELastLibraryRootSearchFrame = CGRectZero;
static CGFloat ALELastLibraryRootListWidth = 0;
static SBHLibrarySearchController *ALECurrentLibrarySearchController = nil;
static NSInteger ALELibraryFolderSearchRefreshTicks = 0;
static BOOL ALELibraryFolderSearchRefreshScheduled = NO;
static SBHSearchBar *ALECurrentLibrarySearchBar = nil;

static void ALELayoutLibrarySearchController(SBHLibrarySearchController *searchController);

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

static void ALELayoutLibrarySearchBar(SBHSearchBar *searchBar) {
	if (![searchBar isKindOfClass:[UIView class]] || CGRectIsEmpty(ALELastLibraryRootSearchFrame) || ALELastLibraryRootListWidth <= 0) {
		return;
	}

	UIView *searchSuperview = searchBar.superview;
	if (![searchSuperview isKindOfClass:[UIView class]]) {
		return;
	}

	CGFloat layoutWidth = CGRectGetWidth(ALECurrentLibrarySearchController.view.bounds);
	if (layoutWidth <= 0) {
		layoutWidth = CGRectGetWidth(searchSuperview.bounds);
	}

	CGFloat scale = layoutWidth / ALELastLibraryRootListWidth;
	if (scale <= 0) {
		scale = 1.0;
	}

	CGFloat targetWidth = round(CGRectGetWidth(ALELastLibraryRootSearchFrame) * scale);
	CGFloat left = round((CGRectGetWidth(searchSuperview.bounds) - targetWidth) * 0.5);
	CGFloat right = left + targetWidth;
	CGFloat superviewWidth = CGRectGetWidth(searchSuperview.bounds);
	if (right <= left || left < -1.0 || right > superviewWidth + 1.0) {
		return;
	}

	CGRect searchFrame = searchBar.frame;
	if (fabs(CGRectGetMinX(searchFrame) - left) <= 1.0 && fabs(CGRectGetWidth(searchFrame) - (right - left)) <= 1.0) {
		return;
	}

	searchFrame.origin.x = left;
	searchFrame.size.width = right - left;
	searchBar.frame = searchFrame;
}

static CGFloat ALELibrarySearchTargetWidthForSearchBar(SBHSearchBar *searchBar) {
	if (![searchBar isKindOfClass:[UIView class]] || CGRectIsEmpty(ALELastLibraryRootSearchFrame) || ALELastLibraryRootListWidth <= 0) {
		return 0;
	}

	UIView *searchSuperview = searchBar.superview;
	CGFloat layoutWidth = CGRectGetWidth(ALECurrentLibrarySearchController.view.bounds);
	if (layoutWidth <= 0 && [searchSuperview isKindOfClass:[UIView class]]) {
		layoutWidth = CGRectGetWidth(searchSuperview.bounds);
	}
	if (layoutWidth <= 0) {
		return 0;
	}

	CGFloat scale = layoutWidth / ALELastLibraryRootListWidth;
	if (scale <= 0) {
		scale = 1.0;
	}

	return round(CGRectGetWidth(ALELastLibraryRootSearchFrame) * scale);
}

static CGFloat ALELayerHorizontalScale(CALayer *layer) {
	if (!layer) {
		return 1.0;
	}

	CATransform3D transform = layer.transform;
	CGFloat scaleX = sqrt((transform.m11 * transform.m11) + (transform.m12 * transform.m12));
	return scaleX > 0 ? scaleX : 1.0;
}

static CGFloat ALEInheritedHorizontalScaleForView(UIView *view) {
	CGFloat scaleX = 1.0;
	UIView *currentView = view.superview;
	while ([currentView isKindOfClass:[UIView class]]) {
		CALayer *presentationLayer = currentView.layer.presentationLayer;
		scaleX *= ALELayerHorizontalScale(presentationLayer ?: currentView.layer);
		currentView = currentView.superview;
	}

	return scaleX > 0 ? scaleX : 1.0;
}

static void ALEApplyLibrarySearchAnimationCompensation(void) {
	SBHSearchBar *searchBar = ALECurrentLibrarySearchBar;
	CGFloat targetWidth = ALELibrarySearchTargetWidthForSearchBar(searchBar);
	if (![searchBar isKindOfClass:[UIView class]] || targetWidth <= 0) {
		return;
	}

	CGFloat inheritedScaleX = ALEInheritedHorizontalScaleForView(searchBar);
	if (fabs(inheritedScaleX - 1.0) <= 0.01) {
		searchBar.transform = CGAffineTransformIdentity;
		return;
	}

	searchBar.transform = CGAffineTransformMakeScale(1.0 / inheritedScaleX, 1.0);
}

static void ALELayoutLibrarySearchController(SBHLibrarySearchController *searchController) {
	if (!searchController.view) {
		return;
	}

	ALECurrentLibrarySearchController = searchController;

	SBHSearchBar *searchBar = ALEValueForKey(searchController, @"_searchBar");
	if ([searchBar isKindOfClass:[UIView class]]) {
		ALECurrentLibrarySearchBar = searchBar;
	}
	UIView *containerView = ALEValueForKey(searchController, @"_containerView");
	UIView *contentContainerView = ALEValueForKey(searchController, @"_contentContainerView");
	UIView *searchResultsContainerView = ALEValueForKey(searchController, @"_searchResultsContainerView");

	CGRect fullFrame = searchController.view.bounds;
	[containerView setFrame:fullFrame];
	[contentContainerView setFrame:fullFrame];
	[searchResultsContainerView setFrame:fullFrame];

	ALELayoutLibrarySearchBar(searchBar);

	if ([searchBar respondsToSelector:@selector(searchTextFieldHorizontalEdgeInsets)] && [searchBar respondsToSelector:@selector(setSearchTextFieldHorizontalEdgeInsets:)]) {
		UIEdgeInsets searchTextFieldHorizontalEdgeInsets = [searchBar searchTextFieldHorizontalEdgeInsets];
		searchTextFieldHorizontalEdgeInsets.left = 23;
		searchTextFieldHorizontalEdgeInsets.right = 23;
		[searchBar setSearchTextFieldHorizontalEdgeInsets:searchTextFieldHorizontalEdgeInsets];
	}
}

static void ALEStartLibraryFolderSearchRefresh(id controller) {
	if (!controller) {
		return;
	}

	ALELibraryFolderSearchRefreshTicks = 28;
	if (!ALELibraryFolderSearchRefreshScheduled && [controller respondsToSelector:@selector(ale_refreshLibrarySearchDuringFolderAnimation)]) {
		ALELibraryFolderSearchRefreshScheduled = YES;
		[controller performSelector:@selector(ale_refreshLibrarySearchDuringFolderAnimation) withObject:nil afterDelay:0];
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
	if ([configuration respondsToSelector:@selector(setNumberOfPortraitColumns:)]) {
		configuration.numberOfPortraitColumns = libraryRootLayout ? 6 : 3;
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
	unsigned long long podRows = ((unsigned long long)iconCount + podColumns - 1) / podColumns;
	gridCellInfo.numberOfUsedColumns = MIN((unsigned long long)gridSize.columns, podColumns * 2);
	gridCellInfo.numberOfUsedRows = MAX((unsigned long long)1, podRows * 2);
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

static SBIconListView *ALELibraryCategoriesRootListViewInView(UIView *view) {
	if ([view isKindOfClass:NSClassFromString(@"SBIconListView")] && ALEIsLibraryCategoriesRootListView((SBIconListView *)view)) {
		return (SBIconListView *)view;
	}

	for (UIView *subview in view.subviews) {
		SBIconListView *listView = ALELibraryCategoriesRootListViewInView(subview);
		if (listView) {
			return listView;
		}
	}

	return nil;
}

static UIScrollView *ALEEnclosingScrollView(UIView *view) {
	UIView *candidate = view.superview;
	while (candidate) {
		if ([candidate isKindOfClass:[UIScrollView class]]) {
			return (UIScrollView *)candidate;
		}
		candidate = candidate.superview;
	}

	return nil;
}

static CGFloat ALEViewMinYInAncestor(UIView *view, UIView *ancestor) {
	CGFloat minY = 0;
	UIView *candidate = view;
	while (candidate && candidate != ancestor) {
		minY += CGRectGetMinY(candidate.frame);
		candidate = candidate.superview;
	}

	return candidate == ancestor ? minY : 0;
}

static void ALEExposeLibraryCategoriesRootVisibleRange(SBIconListView *listView, NSUInteger columnCount, NSUInteger rowCount) {
	if (ALEUpdatingLibraryRootVisibility || !ALEIsLibraryCategoriesRootListView(listView) || columnCount == 0 || rowCount == 0) {
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

static CGFloat ALELayoutLibraryCategoriesRootListView(SBIconListView *listView) {
	if (!ALEIsLibraryCategoriesRootListView(listView) || ![listView respondsToSelector:@selector(icons)] || ![listView respondsToSelector:@selector(iconViewForIcon:)]) {
		return 0;
	}

	NSArray *icons = listView.icons;
	if (![icons isKindOfClass:[NSArray class]] || icons.count == 0) {
		return 0;
	}

	CGFloat listWidth = CGRectGetWidth(listView.bounds);
	if (listWidth <= 0) {
		listWidth = CGRectGetWidth(listView.superview.bounds);
	}
	if (listWidth <= 0) {
		listWidth = ALEFullWidthForView(listView);
	}

	BOOL landscape = ALEIsLandscapeScreen();
	NSUInteger columnCount = landscape ? 4 : 3;
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
		return 0;
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

	NSUInteger rowCount = ((NSUInteger)icons.count + columnCount - 1) / columnCount;
	CGFloat maxY = topY + (rowStep * MAX((NSInteger)rowCount - 1, 0)) + podHeight;
	CGFloat contentMinX = horizontalInset;
	CGFloat contentMaxX = horizontalInset + ((podWidth + columnGap) * MAX((NSInteger)columnCount - 1, 0)) + podWidth;
	ALELastLibraryRootListWidth = listWidth;
	ALELastLibraryRootSearchFrame = CGRectMake(0, 0, contentMaxX - contentMinX, 1);

	ALEExposeLibraryCategoriesRootVisibleRange(listView, columnCount, rowCount);
	for (NSUInteger iconIndex = 0; iconIndex < icons.count; iconIndex++) {
		UIView *iconView = [listView iconViewForIcon:icons[iconIndex]];
		if (![iconView isKindOfClass:[UIView class]]) {
			continue;
		}

		NSUInteger column = iconIndex % columnCount;
		NSUInteger row = iconIndex / columnCount;
		CGRect frame = iconView.frame;
		if (CGRectGetWidth(frame) <= 0 || CGRectGetHeight(frame) <= 0) {
			frame.size = CGSizeMake(podWidth, podHeight);
		}
		frame.origin.x = horizontalInset + ((podWidth + columnGap) * column);
		frame.origin.y = topY + (rowStep * row);
		iconView.frame = frame;
		if (iconView.hidden) {
			iconView.hidden = NO;
		}
		maxY = MAX(maxY, CGRectGetMaxY(frame));
	}

	return maxY;
}

static void ALEUpdateLibraryCategoriesRootScrollRange(SBIconListView *listView, CGFloat contentBottom) {
	if (!ALEIsLibraryCategoriesRootListView(listView) || contentBottom <= 0) {
		return;
	}

	UIScrollView *scrollView = ALEEnclosingScrollView(listView);
	if (!scrollView) {
		return;
	}

	CGFloat bottomPadding = ALEIsLandscapeScreen() ? 28.0 : 32.0;
	CGFloat listMinY = ALEViewMinYInAncestor(listView, scrollView);
	CGFloat desiredHeight = MAX(listMinY + contentBottom + bottomPadding, CGRectGetHeight(scrollView.bounds) + 1.0);

	CGSize contentSize = scrollView.contentSize;
	if (fabs(contentSize.height - desiredHeight) > 1.0) {
		contentSize.height = desiredHeight;
		ALEUpdatingLibraryRootScrollRange = YES;
		@try {
			scrollView.contentSize = contentSize;
		} @finally {
			ALEUpdatingLibraryRootScrollRange = NO;
		}
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
%end

%hook SBIconListView
- (void)setFrame:(CGRect)frame {
	%orig;
	CGFloat contentBottom = ALELayoutLibraryCategoriesRootListView(self);
	ALEUpdateLibraryCategoriesRootScrollRange(self, contentBottom);
}
- (void)setBounds:(CGRect)bounds {
	%orig;
	CGFloat contentBottom = ALELayoutLibraryCategoriesRootListView(self);
	ALEUpdateLibraryCategoriesRootScrollRange(self, contentBottom);
}
- (void)layoutSubviews {
	%orig;
	CGFloat contentBottom = ALELayoutLibraryCategoriesRootListView(self);
	ALEUpdateLibraryCategoriesRootScrollRange(self, contentBottom);
}
- (void)layoutIconsIfNeeded {
	%orig;
	CGFloat contentBottom = ALELayoutLibraryCategoriesRootListView(self);
	ALEUpdateLibraryCategoriesRootScrollRange(self, contentBottom);
}
- (void)layoutIconsIfNeeded:(double)arg1 {
	%orig;
	CGFloat contentBottom = ALELayoutLibraryCategoriesRootListView(self);
	ALEUpdateLibraryCategoriesRootScrollRange(self, contentBottom);
}
- (void)layoutIconsIfNeededUsingAnimator:(id)arg1 options:(unsigned long long)arg2 {
	%orig;
	CGFloat contentBottom = ALELayoutLibraryCategoriesRootListView(self);
	ALEUpdateLibraryCategoriesRootScrollRange(self, contentBottom);
}
- (void)layoutIconsIfNeededWithAnimationType:(long long)arg1 options:(unsigned long long)arg2 {
	%orig;
	CGFloat contentBottom = ALELayoutLibraryCategoriesRootListView(self);
	ALEUpdateLibraryCategoriesRootScrollRange(self, contentBottom);
}
- (void)layoutIconsNow {
	%orig;
	CGFloat contentBottom = ALELayoutLibraryCategoriesRootListView(self);
	ALEUpdateLibraryCategoriesRootScrollRange(self, contentBottom);
}
%end

%hook UIScrollView
- (void)setContentSize:(CGSize)contentSize {
	%orig;
	if (ALEUpdatingLibraryRootScrollRange) {
		return;
	}

	SBIconListView *listView = ALELibraryCategoriesRootListViewInView(self);
	if (!listView) {
		return;
	}

	CGFloat contentBottom = ALELayoutLibraryCategoriesRootListView(listView);
	ALEUpdateLibraryCategoriesRootScrollRange(listView, contentBottom);
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
- (void)viewWillAppear:(bool)arg1 {
	%orig;
	ALEStartLibraryFolderSearchRefresh(self);
}
- (void)viewWillLayoutSubviews {
	%orig;
	ALEStartLibraryFolderSearchRefresh(self);
}
- (void)viewDidLayoutSubviews {
	%orig;
	ALEStartLibraryFolderSearchRefresh(self);
}
- (void)viewDidAppear:(bool)arg1 {
	%orig;
	ALEStartLibraryFolderSearchRefresh(self);
	UIView *containerView = [self containerView];
	CGRect containerFrame = containerView.frame;
	[self.view setFrame:containerFrame];
}
- (void)ale_refreshLibrarySearchDuringFolderAnimation {
	ALELayoutLibrarySearchController(ALECurrentLibrarySearchController);
	ALEApplyLibrarySearchAnimationCompensation();

	if (ALELibraryFolderSearchRefreshTicks > 0) {
		ALELibraryFolderSearchRefreshTicks--;
		[self performSelector:@selector(ale_refreshLibrarySearchDuringFolderAnimation) withObject:nil afterDelay:0.016];
	} else {
		if ([ALECurrentLibrarySearchBar isKindOfClass:[UIView class]]) {
			ALECurrentLibrarySearchBar.transform = CGAffineTransformIdentity;
			ALELayoutLibrarySearchController(ALECurrentLibrarySearchController);
		}
		ALELibraryFolderSearchRefreshScheduled = NO;
	}
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
