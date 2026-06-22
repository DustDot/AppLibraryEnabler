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

@interface SBHAppLibraryVisualConfiguration : NSObject
@property (assign,nonatomic) UIEdgeInsets appSearchTextFieldLayoutInsets;
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
@property (nonatomic, copy) SBHAppLibraryVisualConfiguration *appLibraryVisualConfiguration;
@end

@interface SBIconListGridLayout : NSObject
@property (nonatomic, copy, readonly) SBIconListGridLayoutConfiguration *layoutConfiguration;
@end

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
static BOOL ALEUpdatingLibraryRootLayout = NO;
static BOOL ALEUpdatingLibraryRootScrollRange = NO;
static BOOL ALEUpdatingLibraryRootVisibility = NO;
static NSRange ALELastLibraryRootVisibleColumnRange = {NSNotFound, 0};
static NSRange ALELastLibraryRootVisibleRowRange = {NSNotFound, 0};
static SBIconListView *ALELastLibraryRootVisibleListView = nil;

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

static struct SBHIconGridSize ALELibraryRootGridSize(struct SBHIconGridSize originalGridSize) {
	struct SBHIconGridSize gridSize = originalGridSize;
	unsigned long long podRows = ALEIsLandscapeScreen() ? 4 : 5;

	gridSize.columns = MAX(gridSize.columns, (unsigned short)8);
	gridSize.rows = MAX(gridSize.rows, (unsigned short)(podRows * 2));
	return gridSize;
}

static NSUInteger ALELibraryRootPodColumnCount(void) {
	return 4;
}

static unsigned long long ALELibraryRootPodColumnsForGridSize(struct SBHIconGridSize gridSize) {
	return MAX((unsigned long long)1, (unsigned long long)gridSize.columns / 2);
}

static unsigned long long ALELibraryRootGridCellIndexForIconIndex(NSUInteger iconIndex, struct SBHIconGridSize gridSize) {
	unsigned long long podColumns = ALELibraryRootPodColumnsForGridSize(gridSize);
	unsigned long long row = iconIndex / podColumns;
	unsigned long long column = iconIndex % podColumns;
	return (row * 2 * gridSize.columns) + (column * 2);
}

static void ALEReflowLibraryRootGridCellInfo(SBIconListGridCellInfo *gridCellInfo, NSUInteger iconCount, struct SBHIconGridSize gridSize) {
	if (!gridCellInfo || iconCount == 0 || gridSize.columns == 0) {
		return;
	}

	gridCellInfo.gridSize = gridSize;
	[gridCellInfo clearAllIconAndGridCellIndexes];

	for (NSUInteger iconIndex = 0; iconIndex < iconCount; iconIndex++) {
		unsigned long long gridCellIndex = ALELibraryRootGridCellIndexForIconIndex(iconIndex, gridSize);
		[gridCellInfo setGridCellIndex:gridCellIndex forIconIndex:iconIndex];
		[gridCellInfo setIconIndex:iconIndex forGridCellIndex:gridCellIndex];
		[gridCellInfo setIconIndex:iconIndex forGridCellIndex:gridCellIndex + 1];
		[gridCellInfo setIconIndex:iconIndex forGridCellIndex:gridCellIndex + gridSize.columns];
		[gridCellInfo setIconIndex:iconIndex forGridCellIndex:gridCellIndex + gridSize.columns + 1];
	}

	unsigned long long podColumns = ALELibraryRootPodColumnsForGridSize(gridSize);
	unsigned long long podRows = ((unsigned long long)iconCount + podColumns - 1) / podColumns;
	gridCellInfo.numberOfUsedColumns = MIN((unsigned long long)gridSize.columns, podColumns * 2);
	gridCellInfo.numberOfUsedRows = MAX((unsigned long long)1, podRows * 2);
}

static CGFloat ALELibraryRootContentWidth(CGFloat interfaceWidth) {
	CGFloat width = interfaceWidth * (ALEIsLandscapeScreen() ? 0.66 : 0.64);
	CGFloat minimumWidth = ALEIsLandscapeScreen() ? 820.0 : 600.0;
	CGFloat maximumWidth = ALEIsLandscapeScreen() ? 1040.0 : 760.0;
	return MIN(MAX(width, minimumWidth), MIN(interfaceWidth, maximumWidth));
}

static UIEdgeInsets ALELibraryRootContentInsetsForWidth(CGFloat interfaceWidth) {
	CGFloat rootContentWidth = ALELibraryRootContentWidth(interfaceWidth);
	CGFloat horizontalInset = MAX((CGFloat)0, floor((interfaceWidth - rootContentWidth) / 2.0));
	return UIEdgeInsetsMake(0, horizontalInset, 0, horizontalInset);
}

static CGFloat ALELibraryRootColumnGap(CGFloat podWidth) {
	CGFloat ratioGap = floor(podWidth * (ALEIsLandscapeScreen() ? 0.23 : 0.18));
	CGFloat minimumGap = ALEIsLandscapeScreen() ? 32.0 : 24.0;
	CGFloat maximumGap = ALEIsLandscapeScreen() ? 38.0 : 32.0;
	return MIN(MAX(ratioGap, minimumGap), maximumGap);
}

static CGFloat ALELibraryRootRowGap(CGFloat podHeight) {
	CGFloat ratioGap = floor(podHeight * (ALEIsLandscapeScreen() ? 0.28 : 0.26));
	CGFloat minimumGap = 42.0;
	CGFloat maximumGap = 52.0;
	return MIN(MAX(ratioGap, minimumGap), maximumGap);
}

static UIView *ALEFirstSubviewOfClassNamed(UIView *view, NSString *className) {
	if (![view isKindOfClass:[UIView class]] || !className) {
		return nil;
	}

	if (ALEObjectIsKindOfClassNamed(view, className)) {
		return view;
	}

	for (UIView *subview in view.subviews) {
		UIView *matchedView = ALEFirstSubviewOfClassNamed(subview, className);
		if (matchedView) {
			return matchedView;
		}
	}

	return nil;
}

static CGRect ALELibraryRootFrameForGridInView(UIView *view, CGSize gridSize) {
	UIView *coordinateView = view.window ?: view.superview;
	CGRect bounds = [coordinateView isKindOfClass:[UIView class]] ? coordinateView.bounds : CGRectZero;
	if ((CGRectGetWidth(bounds) <= 0 || CGRectGetHeight(bounds) <= 0) && view) {
		bounds = view.bounds;
	}
	if (CGRectGetWidth(bounds) <= 0 || CGRectGetHeight(bounds) <= 0) {
		CGSize interfaceSize = ALECurrentInterfaceSize();
		bounds = CGRectMake(0, 0, interfaceSize.width, interfaceSize.height);
	}

	CGFloat width = CGRectGetWidth(bounds);
	CGFloat height = CGRectGetHeight(bounds);
	CGFloat targetX = floor((width - gridSize.width) / 2.0);
	CGFloat targetY = floor((height - gridSize.height) / 2.0);
	CGFloat topBoundary = floor(height * (ALEIsLandscapeScreen() ? 0.19 : 0.15));

	UIView *searchBar = ALEFirstSubviewOfClassNamed(coordinateView, @"SBHSearchBar");
	if ([searchBar isKindOfClass:[UIView class]] && !searchBar.hidden && searchBar.alpha > 0.01) {
		CGRect searchFrame = [searchBar convertRect:searchBar.bounds toView:coordinateView];
		if (CGRectGetHeight(searchFrame) > 0) {
			topBoundary = MAX(topBoundary, CGRectGetMaxY(searchFrame) + floor(height * (ALEIsLandscapeScreen() ? 0.035 : 0.03)));
		}
	}

	CGFloat bottomBoundary = height - floor(height * (ALEIsLandscapeScreen() ? 0.035 : 0.04));
	targetY = MAX(topBoundary, targetY);
	if (targetY + gridSize.height > bottomBoundary) {
		targetY = MAX(topBoundary, floor(bottomBoundary - gridSize.height));
	}

	if ([coordinateView isKindOfClass:[UIView class]] && view) {
		CGPoint origin = [view convertPoint:CGPointMake(targetX, targetY) fromView:coordinateView];
		return CGRectMake(floor(origin.x), floor(origin.y), gridSize.width, gridSize.height);
	}

	return CGRectMake(targetX, targetY, gridSize.width, gridSize.height);
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

static NSUInteger ALELibraryRootRowCount(SBIconListView *listView) {
	if (!ALEIsLibraryRootListView(listView) || ![listView respondsToSelector:@selector(icons)]) {
		return 0;
	}

	NSArray *icons = listView.icons;
	if (![icons isKindOfClass:[NSArray class]] || icons.count == 0) {
		return 0;
	}

	NSUInteger columnCount = ALELibraryRootPodColumnCount();
	return ((NSUInteger)icons.count + columnCount - 1) / columnCount;
}

static void ALEExposeLibraryRootVisibleRange(SBIconListView *listView, NSUInteger columnCount, NSUInteger rowCount) {
	if (ALEUpdatingLibraryRootVisibility || !ALEIsLibraryRootListView(listView) || columnCount == 0 || rowCount == 0) {
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

		if (visibilityChanged) {
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
		}
	} @finally {
		ALEUpdatingLibraryRootVisibility = NO;
	}
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

static SBIconListView *ALELibraryRootListViewInView(UIView *view) {
	if ([view isKindOfClass:NSClassFromString(@"SBIconListView")] && ALEIsLibraryRootListView((SBIconListView *)view)) {
		return (SBIconListView *)view;
	}

	for (UIView *subview in view.subviews) {
		SBIconListView *listView = ALELibraryRootListViewInView(subview);
		if (listView) {
			return listView;
		}
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

static void ALEUpdateLibraryRootScrollRange(SBIconListView *listView, CGFloat contentBottom) {
	if (ALEUpdatingLibraryRootScrollRange || !ALEIsLibraryRootListView(listView)) {
		return;
	}

	UIScrollView *scrollView = ALEEnclosingScrollView(listView);
	if (![scrollView isKindOfClass:[UIScrollView class]]) {
		return;
	}

	ALEUpdatingLibraryRootScrollRange = YES;
	@try {
		CGSize contentSize = scrollView.contentSize;
		CGFloat scrollWidth = CGRectGetWidth(scrollView.bounds);
		if (scrollWidth > 0) {
			contentSize.width = scrollWidth;
		}

		if (contentBottom > 0) {
			CGFloat listMinY = ALEViewMinYInAncestor(listView, scrollView);
			CGFloat minimumHeight = CGRectGetHeight(scrollView.bounds) + scrollView.contentInset.top + scrollView.contentInset.bottom;
			contentSize.height = MAX(minimumHeight, listMinY + contentBottom + 24.0);
		}

		scrollView.contentSize = contentSize;
		scrollView.showsHorizontalScrollIndicator = NO;
		scrollView.alwaysBounceHorizontal = NO;

		CGPoint contentOffset = scrollView.contentOffset;
		if (fabs(contentOffset.x) > 0.5) {
			contentOffset.x = 0;
			scrollView.contentOffset = contentOffset;
		}
	} @finally {
		ALEUpdatingLibraryRootScrollRange = NO;
	}
}

static CGFloat ALELayoutLibraryRootListView(SBIconListView *listView) {
	if (ALEUpdatingLibraryRootLayout || !ALEIsLibraryRootListView(listView) || ![listView respondsToSelector:@selector(icons)] || ![listView respondsToSelector:@selector(iconViewForIcon:)]) {
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
		listWidth = ALEInterfaceWidthForView(listView);
	}

	NSUInteger columnCount = ALELibraryRootPodColumnCount();
	BOOL foundPodFrame = NO;
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
		foundPodFrame = YES;
	}

	if (podWidth <= 0 || podHeight <= 0 || !foundPodFrame || columnCount == 0) {
		return 0;
	}

	CGFloat columnGap = ALELibraryRootColumnGap(podWidth);
	CGFloat gridWidth = (podWidth * columnCount) + (columnGap * (columnCount - 1));
	gridWidth = MIN(gridWidth, listWidth);
	CGFloat gridLeft = floor((listWidth - gridWidth) / 2.0);
	columnGap = columnCount > 1 ? (gridWidth - (podWidth * columnCount)) / (CGFloat)(columnCount - 1) : 0;

	CGFloat rowStep = podHeight + ALELibraryRootRowGap(podHeight);

	NSUInteger rowCount = ALELibraryRootRowCount(listView);
	CGFloat gridHeight = podHeight + (rowStep * MAX((NSInteger)rowCount - 1, 0));
	CGRect gridFrame = ALELibraryRootFrameForGridInView(listView, CGSizeMake(gridWidth, gridHeight));
	gridLeft = CGRectGetMinX(gridFrame);
	CGFloat topY = CGRectGetMinY(gridFrame);
	CGFloat maxY = topY + (rowStep * MAX((NSInteger)rowCount - 1, 0)) + podHeight;

	ALEExposeLibraryRootVisibleRange(listView, columnCount, rowCount);

	ALEUpdatingLibraryRootLayout = YES;
	@try {
		for (NSUInteger iconIndex = 0; iconIndex < icons.count; iconIndex++) {
			UIView *iconView = [listView iconViewForIcon:[icons objectAtIndex:iconIndex]];
			if (![iconView isKindOfClass:[UIView class]]) {
				continue;
			}

			NSUInteger column = iconIndex % columnCount;
			NSUInteger row = iconIndex / columnCount;
			CGRect frame = iconView.frame;
			frame.origin.x = gridLeft + ((podWidth + columnGap) * column);
			frame.origin.y = topY + (rowStep * row);
			iconView.frame = frame;
		}
	} @finally {
		ALEUpdatingLibraryRootLayout = NO;
	}

	return maxY;
}

static void ALEConfigureAppLibraryGrid(SBIconListGridLayoutConfiguration *configuration, BOOL rootLayout) {
	if (!configuration) {
		return;
	}

	CGSize screenSize = ALECurrentInterfaceSize();
	CGFloat interfaceWidth = screenSize.width;
	CGFloat interfaceHeight = screenSize.height;
	CGFloat rootContentWidth = ALELibraryRootContentWidth(interfaceWidth);
	UIEdgeInsets rootContentInsets = ALELibraryRootContentInsetsForWidth(interfaceWidth);
	CGSize spacingSize = CGSizeMake(rootLayout ? rootContentWidth : interfaceWidth, interfaceHeight);

	if ([configuration respondsToSelector:@selector(setNumberOfLandscapeColumns:)]) {
		configuration.numberOfLandscapeColumns = rootLayout ? 8 : 4;
	}
	if ([configuration respondsToSelector:@selector(setNumberOfLandscapeRows:)]) {
		configuration.numberOfLandscapeRows = rootLayout ? 8 : 4;
	}
	if ([configuration respondsToSelector:@selector(setNumberOfPortraitColumns:)]) {
		configuration.numberOfPortraitColumns = rootLayout ? 8 : 3;
	}
	if ([configuration respondsToSelector:@selector(setNumberOfPortraitRows:)]) {
		configuration.numberOfPortraitRows = rootLayout ? 10 : 5;
	}
	if ([configuration respondsToSelector:@selector(setListSizeForIconSpacingCalculation:)]) {
		configuration.listSizeForIconSpacingCalculation = spacingSize;
	}
	if ([configuration respondsToSelector:@selector(setLandscapeLayoutInsets:)]) {
		UIEdgeInsets insets = configuration.landscapeLayoutInsets;
		insets.left = rootLayout ? rootContentInsets.left : MAX((CGFloat)96.0, interfaceWidth * 0.11);
		insets.right = insets.left;
		configuration.landscapeLayoutInsets = insets;
	}
	if ([configuration respondsToSelector:@selector(setPortraitLayoutInsets:)]) {
		UIEdgeInsets insets = configuration.portraitLayoutInsets;
		insets.left = rootLayout ? rootContentInsets.left : MAX((CGFloat)72.0, interfaceWidth * 0.105);
		insets.right = insets.left;
		configuration.portraitLayoutInsets = insets;
	}
	if (rootLayout && [configuration respondsToSelector:@selector(appLibraryVisualConfiguration)]) {
		SBHAppLibraryVisualConfiguration *visualConfiguration = configuration.appLibraryVisualConfiguration;
		if ([visualConfiguration respondsToSelector:@selector(setAppSearchTextFieldLayoutInsets:)]) {
			visualConfiguration.appSearchTextFieldLayoutInsets = rootContentInsets;
		}
	}
}

static void ALEConfigureLayoutForLibraryRoot(id layout) {
	if (![layout respondsToSelector:@selector(layoutConfiguration)]) {
		return;
	}

	SBIconListGridLayoutConfiguration *configuration = [layout layoutConfiguration];
	ALEConfigureAppLibraryGrid(configuration, YES);
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
	ALEConfigureAppLibraryGrid(configuration, ALEConfiguringLibraryRootLayout);
}
-(id)makeLayoutForIconLocation:(id)iconLocation {
	BOOL previousRootLayout = ALEConfiguringLibraryRootLayout;
	ALEConfiguringLibraryRootLayout = ALEIsLibraryRootIconLocation(iconLocation);
	id layout = %orig;
	ALEConfiguringLibraryRootLayout = previousRootLayout;
	if (ALEIsLibraryRootIconLocation(iconLocation)) {
		ALEConfigureLayoutForLibraryRoot(layout);
	}
	return layout;
}
-(id)layoutForIconLocation:(id)iconLocation {
	BOOL previousRootLayout = ALEConfiguringLibraryRootLayout;
	ALEConfiguringLibraryRootLayout = ALEIsLibraryRootIconLocation(iconLocation);
	id layout = %orig;
	ALEConfiguringLibraryRootLayout = previousRootLayout;
	if (ALEIsLibraryRootIconLocation(iconLocation)) {
		ALEConfigureLayoutForLibraryRoot(layout);
	}
	return layout;
}
%end

%hook SBFolder
-(struct SBHIconGridSize)listGridSize {
	struct SBHIconGridSize gridSize = %orig;
	if (ALEIsLibraryCategoriesRootFolder(self)) {
		return ALELibraryRootGridSize(gridSize);
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

	return gridSize;
}
-(id)gridCellInfoForGridSize:(struct SBHIconGridSize)gridSize options:(unsigned long long)options {
	if (ALEIsLibraryCategoriesRootFolder(self.folder)) {
		struct SBHIconGridSize rootGridSize = ALELibraryRootGridSize(gridSize);
		id gridCellInfo = %orig(rootGridSize, options);
		ALEReflowLibraryRootGridCellInfo((SBIconListGridCellInfo *)gridCellInfo, self.numberOfIcons, rootGridSize);
		return gridCellInfo;
	}

	return %orig;
}
%end

%hook SBIconListView
- (void)setVisibleColumnRange:(NSRange)range {
	if (ALEIsLibraryRootListView(self)) {
		range = NSMakeRange(0, ALELibraryRootPodColumnCount() * 2);
	}
	%orig(range);
}
- (void)setVisibleRowRange:(NSRange)range {
	NSUInteger rowCount = ALELibraryRootRowCount(self);
	if (rowCount > 0) {
		range = NSMakeRange(0, rowCount * 2);
	}
	%orig(range);
}
- (void)setFrame:(CGRect)frame {
	%orig;
	CGFloat contentBottom = ALELayoutLibraryRootListView(self);
	ALEUpdateLibraryRootScrollRange(self, contentBottom);
}
- (void)setBounds:(CGRect)bounds {
	%orig;
	CGFloat contentBottom = ALELayoutLibraryRootListView(self);
	ALEUpdateLibraryRootScrollRange(self, contentBottom);
}
- (void)layoutSubviews {
	%orig;
	CGFloat contentBottom = ALELayoutLibraryRootListView(self);
	ALEUpdateLibraryRootScrollRange(self, contentBottom);
}
- (void)layoutIconsIfNeeded {
	%orig;
	CGFloat contentBottom = ALELayoutLibraryRootListView(self);
	ALEUpdateLibraryRootScrollRange(self, contentBottom);
}
- (void)layoutIconsNow {
	%orig;
	CGFloat contentBottom = ALELayoutLibraryRootListView(self);
	ALEUpdateLibraryRootScrollRange(self, contentBottom);
}
%end

%hook UIScrollView
- (void)setContentSize:(CGSize)contentSize {
	if (!ALEUpdatingLibraryRootScrollRange) {
		SBIconListView *listView = ALELibraryRootListViewInView(self);
		if (listView) {
			CGFloat scrollWidth = CGRectGetWidth(self.bounds);
			if (scrollWidth > 0) {
				contentSize.width = scrollWidth;
			}
		}
	}
	%orig(contentSize);
}
- (void)setContentOffset:(CGPoint)contentOffset {
	if (!ALEUpdatingLibraryRootScrollRange) {
		SBIconListView *listView = ALELibraryRootListViewInView(self);
		if (listView) {
			contentOffset.x = 0;
		}
	}
	%orig(contentOffset);
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
	if (strcmp(domain, "SpringBoard") == 0 && strcmp(feature, "Dewey") == 0) {
		return true;
	}
	return %orig;
}

%ctor {
	%init;
}
