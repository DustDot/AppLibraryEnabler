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
- (bool)isActive;
- (void)setActive:(bool)active animated:(bool)animated;
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
static NSRange ALELastLibraryRootVisibleColumnRange = {NSNotFound, 0};
static NSRange ALELastLibraryRootVisibleRowRange = {NSNotFound, 0};
static SBIconListView *ALELastLibraryRootVisibleListView = nil;
static CGFloat ALELastLibraryRootGridMinX = 0;
static CGFloat ALELastLibraryRootGridWidth = 0;
static CGFloat ALELastLibraryRootListWidth = 0;
static NSUInteger ALELastLibraryRootColumnCount = 0;
static BOOL ALELastLibraryRootLandscape = NO;
static SBHSearchBar *ALELastLibrarySearchBar = nil;
static SBHLibrarySearchController *ALELastLibrarySearchController = nil;
static BOOL ALEApplyingLibrarySearchBarLayout = NO;
static BOOL ALELibraryPodFolderPresentedOrAnimating = NO;

static BOOL ALEIsLandscapeScreen(void);
static NSUInteger ALELibraryCategoriesRootColumnCount(void);
static BOOL ALEHasLibraryRootGridWidth(void);
static void ALEApplyLibrarySearchBarLayout(SBHSearchBar *searchBar);
static void ALELayoutLibrarySearchBarVisibleContent(SBHSearchBar *searchBar);
static BOOL ALELibrarySearchIsActive(void);
static BOOL ALELibrarySearchShouldDeferSearchBarFrame(SBHSearchBar *searchBar);
static BOOL ALEViewContainsActiveTextField(UIView *view);
static void ALEConstrainLibrarySearchResultsView(UIView *view, CGRect gridFrame, CGRect fullFrame);

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

	ALELastLibrarySearchController = searchController;
	SBHSearchBar *searchBar = ALEValueForKey(searchController, @"_searchBar");
	if ([searchBar isKindOfClass:[UIView class]]) {
		ALELastLibrarySearchBar = searchBar;
	}
	UIView *containerView = ALEValueForKey(searchController, @"_containerView");
	UIView *contentContainerView = ALEValueForKey(searchController, @"_contentContainerView");
	UIView *searchResultsContainerView = ALEValueForKey(searchController, @"_searchResultsContainerView");

	CGRect fullFrame = searchController.view.bounds;
	[containerView setFrame:fullFrame];
	[contentContainerView setFrame:fullFrame];
	[searchResultsContainerView setFrame:fullFrame];
	if (ALELibrarySearchIsActive() && ALEHasLibraryRootGridWidth() && ALELastLibraryRootGridWidth > 0) {
		CGRect gridFrame = fullFrame;
		gridFrame.size.width = MIN(CGRectGetWidth(fullFrame), ALELastLibraryRootGridWidth);
		gridFrame.origin.x = (CGRectGetWidth(fullFrame) - CGRectGetWidth(gridFrame)) / 2.0;
		ALEConstrainLibrarySearchResultsView(searchResultsContainerView, gridFrame, fullFrame);
	}

	if ([searchBar respondsToSelector:@selector(searchTextFieldHorizontalEdgeInsets)] && [searchBar respondsToSelector:@selector(setSearchTextFieldHorizontalEdgeInsets:)]) {
		UIEdgeInsets searchTextFieldHorizontalEdgeInsets = [searchBar searchTextFieldHorizontalEdgeInsets];
		searchTextFieldHorizontalEdgeInsets.left = 23;
		searchTextFieldHorizontalEdgeInsets.right = 23;
		[searchBar setSearchTextFieldHorizontalEdgeInsets:searchTextFieldHorizontalEdgeInsets];
	}

	ALEApplyLibrarySearchBarLayout(searchBar);
}

static BOOL ALELibrarySearchIsActive(void) {
	SBHLibrarySearchController *searchController = ALELastLibrarySearchController;
	if (![searchController isKindOfClass:[UIViewController class]]) {
		return NO;
	}

	if (![searchController respondsToSelector:@selector(isActive)]) {
		return NO;
	}

	return [searchController isActive];
}

static BOOL ALELibrarySearchShouldDeferSearchBarFrame(SBHSearchBar *searchBar) {
	return ALELibrarySearchIsActive() || ALEViewContainsActiveTextField(searchBar);
}

static BOOL ALEViewContainsActiveTextField(UIView *view) {
	if (![view isKindOfClass:[UIView class]] || view.hidden || view.alpha <= 0.01) {
		return NO;
	}

	if ([view isKindOfClass:[UITextField class]]) {
		UITextField *textField = (UITextField *)view;
		if (textField.isEditing || textField.isFirstResponder) {
			return YES;
		}
	}

	for (UIView *subview in view.subviews) {
		if (ALEViewContainsActiveTextField(subview)) {
			return YES;
		}
	}

	return NO;
}

static void ALEConstrainLibrarySearchResultsView(UIView *view, CGRect gridFrame, CGRect fullFrame) {
	if (![view isKindOfClass:[UIView class]] || view.hidden || view.alpha <= 0.01) {
		return;
	}

	for (UIView *subview in view.subviews) {
		CGRect frame = subview.frame;
		CGFloat width = CGRectGetWidth(frame);
		BOOL spansFullWidth = width > CGRectGetWidth(gridFrame) + 20.0 && width <= CGRectGetWidth(fullFrame) + 20.0;
		BOOL isResultContent = CGRectGetHeight(frame) > 80.0 && CGRectGetMaxY(frame) > 120.0;
		if (spansFullWidth && isResultContent) {
			frame.origin.x = CGRectGetMinX(gridFrame);
			frame.size.width = CGRectGetWidth(gridFrame);
			[subview setFrame:frame];
			continue;
		}

		ALEConstrainLibrarySearchResultsView(subview, gridFrame, fullFrame);
	}
}

static BOOL ALEHasLibraryRootGridWidth(void) {
	if (ALELastLibraryRootGridWidth <= 0 || ALELastLibraryRootListWidth <= 0) {
		return NO;
	}

	if (ALELastLibraryRootColumnCount != ALELibraryCategoriesRootColumnCount()) {
		return NO;
	}

	return ALELastLibraryRootLandscape == ALEIsLandscapeScreen();
}

static CGFloat ALELibrarySearchTargetWidth(CGFloat referenceWidth) {
	if (!ALEHasLibraryRootGridWidth() || referenceWidth <= 0) {
		return 0;
	}

	CGFloat targetWidth = ALELastLibraryRootGridWidth;
	if (ALELastLibraryRootGridMinX > 0 && ALELastLibraryRootListWidth > 0 && fabs(referenceWidth - ALELastLibraryRootListWidth) <= 2.0) {
		CGFloat symmetricWidth = ALELastLibraryRootListWidth - (ALELastLibraryRootGridMinX * 2.0);
		if (symmetricWidth > targetWidth && symmetricWidth <= ALELastLibraryRootListWidth) {
			targetWidth = symmetricWidth;
		}
	}
	if (targetWidth <= 0) {
		return 0;
	}

	return targetWidth;
}

static CGRect ALELibrarySearchTargetFrame(SBHSearchBar *searchBar, CGRect frame) {
	if (ALEApplyingLibrarySearchBarLayout || searchBar != ALELastLibrarySearchBar || !searchBar.superview) {
		return frame;
	}

	if (ALELibrarySearchShouldDeferSearchBarFrame(searchBar)) {
		return frame;
	}

	CGFloat referenceWidth = CGRectGetWidth(searchBar.superview.bounds);
	CGFloat targetWidth = ALELibrarySearchTargetWidth(referenceWidth);
	if (targetWidth <= 0) {
		return frame;
	}

	frame.size.width = targetWidth;
	frame.origin.x = ALELastLibraryRootGridMinX > 0 && fabs(referenceWidth - ALELastLibraryRootListWidth) <= 2.0 ? ALELastLibraryRootGridMinX : (referenceWidth - targetWidth) / 2.0;
	return frame;
}

static CGPoint ALELibrarySearchTargetCenter(SBHSearchBar *searchBar, CGPoint center) {
	if (ALEApplyingLibrarySearchBarLayout || searchBar != ALELastLibrarySearchBar || !searchBar.superview) {
		return center;
	}

	if (ALELibrarySearchShouldDeferSearchBarFrame(searchBar)) {
		return center;
	}

	CGFloat referenceWidth = CGRectGetWidth(searchBar.superview.bounds);
	CGRect targetFrame = ALELibrarySearchTargetFrame(searchBar, searchBar.frame);
	if (ALELibrarySearchTargetWidth(referenceWidth) <= 0) {
		return center;
	}

	center.x = CGRectGetMidX(targetFrame);
	return center;
}

static CGRect ALELibrarySearchTargetBounds(SBHSearchBar *searchBar, CGRect bounds) {
	if (ALEApplyingLibrarySearchBarLayout || searchBar != ALELastLibrarySearchBar || !searchBar.superview) {
		return bounds;
	}

	if (ALELibrarySearchShouldDeferSearchBarFrame(searchBar)) {
		return bounds;
	}

	CGFloat referenceWidth = CGRectGetWidth(searchBar.superview.bounds);
	CGFloat targetWidth = ALELibrarySearchTargetWidth(referenceWidth);
	if (targetWidth <= 0) {
		return bounds;
	}

	bounds.size.width = targetWidth;
	return bounds;
}

static CGAffineTransform ALELibrarySearchTargetTransform(SBHSearchBar *searchBar, CGAffineTransform transform) {
	if (searchBar != ALELastLibrarySearchBar || !ALELibraryPodFolderPresentedOrAnimating) {
		return transform;
	}

	transform.a = 1.0;
	transform.b = 0;
	transform.c = 0;
	transform.d = 1.0;
	return transform;
}

static void ALEApplyLibrarySearchBarLayout(SBHSearchBar *searchBar) {
	if (ALEApplyingLibrarySearchBarLayout || searchBar != ALELastLibrarySearchBar || !searchBar.superview) {
		return;
	}

	CGRect targetFrame = ALELibrarySearchTargetFrame(searchBar, searchBar.frame);
	BOOL frameNeedsUpdate = fabs(CGRectGetMinX(searchBar.frame) - CGRectGetMinX(targetFrame)) > 0.5;
	frameNeedsUpdate = frameNeedsUpdate || fabs(CGRectGetWidth(searchBar.frame) - CGRectGetWidth(targetFrame)) > 0.5;

	CGPoint targetCenter = ALELibrarySearchTargetCenter(searchBar, searchBar.center);
	BOOL centerNeedsUpdate = fabs(searchBar.center.x - targetCenter.x) > 0.5;
	BOOL transformNeedsUpdate = ALELibraryPodFolderPresentedOrAnimating && !CGAffineTransformIsIdentity(searchBar.transform);
	if (!frameNeedsUpdate && !centerNeedsUpdate && !transformNeedsUpdate) {
		ALELayoutLibrarySearchBarVisibleContent(searchBar);
		return;
	}

	ALEApplyingLibrarySearchBarLayout = YES;
	@try {
		if (frameNeedsUpdate) {
			[searchBar setFrame:targetFrame];
		}

		if (centerNeedsUpdate) {
			[searchBar setCenter:targetCenter];
		}

		if (transformNeedsUpdate) {
			[searchBar setTransform:CGAffineTransformIdentity];
		}

		ALELayoutLibrarySearchBarVisibleContent(searchBar);
	} @finally {
		ALEApplyingLibrarySearchBarLayout = NO;
	}
}

static void ALEBeginLibraryPodFolderPresentation(void) {
	ALELibraryPodFolderPresentedOrAnimating = YES;
	ALEApplyLibrarySearchBarLayout(ALELastLibrarySearchBar);
}

static void ALEEndLibraryPodFolderPresentation(void) {
	ALELibraryPodFolderPresentedOrAnimating = NO;
	ALEApplyLibrarySearchBarLayout(ALELastLibrarySearchBar);
}

static BOOL ALEUnionVisibleBoundsInView(UIView *view, UIView *targetView, CGRect *bounds) {
	if (![view isKindOfClass:[UIView class]] || view.hidden || view.alpha <= 0.01 || !targetView || !bounds) {
		return NO;
	}

	BOOL hasBounds = NO;
	CGRect viewBounds = [view convertRect:view.bounds toView:targetView];
	if (CGRectGetWidth(viewBounds) > 1.0 && CGRectGetHeight(viewBounds) > 1.0) {
		*bounds = viewBounds;
		hasBounds = YES;
	}

	for (UIView *subview in view.subviews) {
		CGRect subviewBounds = CGRectMake(0, 0, 0, 0);
		if (!ALEUnionVisibleBoundsInView(subview, targetView, &subviewBounds)) {
			continue;
		}

		*bounds = hasBounds ? CGRectUnion(*bounds, subviewBounds) : subviewBounds;
		hasBounds = YES;
	}

	return hasBounds;
}

static BOOL ALELargestVisibleSubviewBoundsInView(UIView *view, UIView *targetView, CGRect *bounds) {
	if (![view isKindOfClass:[UIView class]] || !targetView || !bounds) {
		return NO;
	}

	BOOL hasBounds = NO;
	CGFloat largestArea = 0;
	for (UIView *subview in view.subviews) {
		CGRect subviewBounds = CGRectMake(0, 0, 0, 0);
		if (!ALEUnionVisibleBoundsInView(subview, targetView, &subviewBounds)) {
			continue;
		}

		CGFloat area = CGRectGetWidth(subviewBounds) * CGRectGetHeight(subviewBounds);
		if (area > largestArea) {
			*bounds = subviewBounds;
			largestArea = area;
			hasBounds = YES;
		}
	}

	return hasBounds;
}

static void ALELayoutLibrarySearchBarVisibleContent(SBHSearchBar *searchBar) {
	if (![searchBar isKindOfClass:[UIView class]] || CGRectGetWidth(searchBar.bounds) <= 0) {
		return;
	}

	if (ALELibrarySearchShouldDeferSearchBarFrame(searchBar)) {
		return;
	}

	CGRect visibleBounds = CGRectMake(0, 0, 0, 0);
	if (!ALELargestVisibleSubviewBoundsInView(searchBar, searchBar, &visibleBounds)) {
		return;
	}

	CGFloat targetWidth = ALELastLibraryRootGridWidth > 0 ? ALELastLibraryRootGridWidth : CGRectGetWidth(searchBar.bounds);
	CGFloat targetHeight = CGRectGetHeight(visibleBounds);
	if (targetWidth <= 0 || targetHeight <= 0) {
		return;
	}

	for (UIView *subview in searchBar.subviews) {
		CGRect subviewBounds = CGRectMake(0, 0, 0, 0);
		if (!ALEUnionVisibleBoundsInView(subview, searchBar, &subviewBounds)) {
			continue;
		}

		CGFloat widthDelta = fabs(CGRectGetWidth(subviewBounds) - CGRectGetWidth(visibleBounds));
		CGFloat heightDelta = fabs(CGRectGetHeight(subviewBounds) - CGRectGetHeight(visibleBounds));
		if (widthDelta > 1.0 || heightDelta > 1.0) {
			continue;
		}

		CGRect frame = subview.frame;
		frame.origin.x = 0;
		frame.size.width = targetWidth;
		[subview setFrame:frame];
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

static NSUInteger ALELibraryCategoriesRootColumnCount(void) {
	return ALEIsLandscapeScreen() ? 4 : 3;
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

static NSUInteger ALELibraryCategoriesRootRowCount(SBIconListView *listView) {
	if (!ALEIsLibraryCategoriesRootListView(listView) || ![listView respondsToSelector:@selector(icons)]) {
		return 0;
	}

	NSArray *icons = listView.icons;
	if (![icons isKindOfClass:[NSArray class]] || icons.count == 0) {
		return 0;
	}

	NSUInteger columnCount = ALELibraryCategoriesRootColumnCount();
	return ((NSUInteger)icons.count + columnCount - 1) / columnCount;
}

static NSRange ALEExpandedLibraryRootColumnRange(SBIconListView *listView, NSRange proposedRange) {
	if (!ALEIsLibraryCategoriesRootListView(listView)) {
		return proposedRange;
	}

	NSUInteger columnCount = ALELibraryCategoriesRootColumnCount();
	if (columnCount == 0) {
		return proposedRange;
	}

	return NSMakeRange(0, columnCount * 2);
}

static NSRange ALEExpandedLibraryRootRowRange(SBIconListView *listView, NSRange proposedRange) {
	NSUInteger rowCount = ALELibraryCategoriesRootRowCount(listView);
	if (rowCount == 0) {
		return proposedRange;
	}

	return NSMakeRange(0, rowCount * 2);
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
		if (ALELastLibraryRootVisibleListView != listView) {
			ALELastLibraryRootVisibleListView = listView;
			ALELastLibraryRootVisibleColumnRange = NSMakeRange(NSNotFound, 0);
			ALELastLibraryRootVisibleRowRange = NSMakeRange(NSNotFound, 0);
		}

		NSRange visibleColumnRange = NSMakeRange(0, columnCount * 2);
		NSRange visibleRowRange = NSMakeRange(0, rowCount * 2);
		BOOL visibilityChanged = !NSEqualRanges(ALELastLibraryRootVisibleColumnRange, visibleColumnRange) || !NSEqualRanges(ALELastLibraryRootVisibleRowRange, visibleRowRange);

		if (!visibilityChanged) {
			return;
		}

		if ([listView respondsToSelector:@selector(setVisibleColumnRange:)]) {
			listView.visibleColumnRange = visibleColumnRange;
		}
		if ([listView respondsToSelector:@selector(setVisibleRowRange:)]) {
			listView.visibleRowRange = visibleRowRange;
		}
		if ([listView respondsToSelector:@selector(showAllIcons)]) {
			[listView showAllIcons];
		}
		ALELastLibraryRootVisibleColumnRange = visibleColumnRange;
		ALELastLibraryRootVisibleRowRange = visibleRowRange;
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
	NSUInteger columnCount = ALELibraryCategoriesRootColumnCount();
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

	ALEExposeLibraryCategoriesRootVisibleRange(listView, columnCount, rowCount);
	CGFloat gridMinX = CGFLOAT_MAX;
	CGFloat gridMaxX = 0;
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
		gridMinX = MIN(gridMinX, CGRectGetMinX(frame));
		gridMaxX = MAX(gridMaxX, CGRectGetMaxX(frame));
		maxY = MAX(maxY, CGRectGetMaxY(frame));
	}

	if (gridMinX != CGFLOAT_MAX && gridMaxX > gridMinX) {
		ALELastLibraryRootGridMinX = gridMinX;
		ALELastLibraryRootGridWidth = gridMaxX - gridMinX;
		ALELastLibraryRootListWidth = listWidth;
		ALELastLibraryRootColumnCount = columnCount;
		ALELastLibraryRootLandscape = landscape;
		ALEApplyLibrarySearchBarLayout(ALELastLibrarySearchBar);
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
- (void)setVisibleColumnRange:(NSRange)range {
	%orig(ALEExpandedLibraryRootColumnRange(self, range));
}
- (void)setVisibleRowRange:(NSRange)range {
	%orig(ALEExpandedLibraryRootRowRange(self, range));
}
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

	CGFloat contentBottom = 0;
	if ([listView respondsToSelector:@selector(icons)] && [listView respondsToSelector:@selector(iconViewForIcon:)]) {
		for (id icon in listView.icons) {
			UIView *iconView = [listView iconViewForIcon:icon];
			if ([iconView isKindOfClass:[UIView class]] && !iconView.hidden) {
				contentBottom = MAX(contentBottom, CGRectGetMaxY(iconView.frame));
			}
		}
	}
	ALEUpdateLibraryCategoriesRootScrollRange(listView, contentBottom);
}
%end

%hook SBHSearchBar
- (void)setFrame:(CGRect)frame {
	%orig(ALELibrarySearchTargetFrame(self, frame));
}
- (void)setBounds:(CGRect)bounds {
	%orig(ALELibrarySearchTargetBounds(self, bounds));
}
- (void)setCenter:(CGPoint)center {
	%orig(ALELibrarySearchTargetCenter(self, center));
}
- (void)setTransform:(CGAffineTransform)transform {
	%orig(ALELibrarySearchTargetTransform(self, transform));
}
- (void)layoutSubviews {
	%orig;
	ALEApplyLibrarySearchBarLayout(self);
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
- (void)setActive:(bool)active animated:(bool)animated {
	%orig;
	ALELayoutLibrarySearchController(self);
}
%end

%hook SBHLibraryPodFolderController
- (void)viewWillAppear:(bool)arg1 {
	ALEBeginLibraryPodFolderPresentation();
	%orig;
}
- (void)viewDidAppear:(bool)arg1 {
	%orig;
	UIView *containerView = [self containerView];
	CGRect containerFrame = containerView.frame;
	[self.view setFrame:containerFrame];
}
- (void)viewWillDisappear:(bool)arg1 {
	ALEBeginLibraryPodFolderPresentation();
	%orig;
}
- (void)viewDidDisappear:(bool)arg1 {
	%orig;
	ALEEndLibraryPodFolderPresentation();
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
