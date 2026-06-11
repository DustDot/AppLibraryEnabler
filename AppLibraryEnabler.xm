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

@interface SBIconListView : UIView
@property (nonatomic,copy) NSString * iconLocation;
- (CGRect)iconLayoutRect;
- (UIEdgeInsets)layoutInsetsForOrientation:(long long)orientation;
- (CGSize)iconSpacing;
- (CGSize)effectiveIconSpacing;
- (unsigned long long)iconColumnsForCurrentOrientation;
- (unsigned long long)iconsInRowForSpacingCalculation;
@end

@interface SBIconListViewLayoutMetrics : NSObject
@property (nonatomic) unsigned long long columns;
@property (nonatomic) unsigned long long columnsUsedForLayout;
@property (nonatomic) UIEdgeInsets iconInsets;
@property (nonatomic) CGSize iconSpacing;
@end

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

static BOOL ALEIsLandscape(void) {
	CGSize screenSize = [UIScreen mainScreen].bounds.size;
	return screenSize.width > screenSize.height;
}

static unsigned long long ALELibraryColumnCount(void) {
	return ALEIsLandscape() ? 4 : 3;
}

static UIEdgeInsets ALELibraryLayoutInsets(UIEdgeInsets originalInsets) {
	CGFloat horizontalInset = ALEIsLandscape() ? 72 : 48;
	originalInsets.left = horizontalInset;
	originalInsets.right = horizontalInset;
	return originalInsets;
}

static BOOL ALEIsLibraryPodPreviewList(SBIconListView *listView) {
	return ALEObjectIsKindOfClassNamed(listView, @"_SBHLibraryPodCategoryIconListView");
}

static BOOL ALEIsLibraryIconList(SBIconListView *listView) {
	if (!listView) {
		return NO;
	}

	if (ALEObjectIsKindOfClassNamed(listView, @"_SBHLibraryPodIconListView") || ALEObjectIsKindOfClassNamed(listView, @"SBHLibraryCategoryPodIconListView")) {
		return YES;
	}

	NSString *iconLocation = nil;
	if ([listView respondsToSelector:@selector(iconLocation)]) {
		iconLocation = [listView iconLocation];
	}

	return [iconLocation isKindOfClass:[NSString class]] && [iconLocation rangeOfString:@"Library" options:NSCaseInsensitiveSearch].location != NSNotFound;
}

static CGFloat ALELibraryIconListWidth(SBIconListView *listView) {
	CGFloat width = ALEFullWidthForView(listView);
	UIWindow *window = listView.window;
	if (window) {
		width = MAX(width, CGRectGetWidth(window.bounds));
	}
	return width;
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
	CGRect frame = self.view.frame;
	CGFloat fullWidth = ALEFullWidthForView(self.view);
	if (fullWidth > CGRectGetWidth(frame)) {
		frame.size.width = fullWidth;
		self.view.frame = frame;
	}
}
%end

%hook SBIconListView
- (unsigned long long)iconColumnsForCurrentOrientation {
	if (ALEIsLibraryIconList(self) && !ALEIsLibraryPodPreviewList(self)) {
		return ALELibraryColumnCount();
	}

	return %orig;
}
- (unsigned long long)iconsInRowForSpacingCalculation {
	if (ALEIsLibraryIconList(self) && !ALEIsLibraryPodPreviewList(self)) {
		return ALELibraryColumnCount();
	}

	return %orig;
}
- (UIEdgeInsets)layoutInsetsForOrientation:(long long)orientation {
	UIEdgeInsets origValue = %orig;
	if (ALEIsLibraryIconList(self) && !ALEIsLibraryPodPreviewList(self)) {
		return ALELibraryLayoutInsets(origValue);
	}

	return origValue;
}
- (SBIconListViewLayoutMetrics *)layoutMetrics {
	SBIconListViewLayoutMetrics *origValue = %orig;
	if (ALEIsLibraryIconList(self) && !ALEIsLibraryPodPreviewList(self) && [origValue respondsToSelector:@selector(setColumns:)] && [origValue respondsToSelector:@selector(setColumnsUsedForLayout:)]) {
		unsigned long long columns = ALELibraryColumnCount();
		origValue.columns = columns;
		origValue.columnsUsedForLayout = columns;
		if ([origValue respondsToSelector:@selector(setIconInsets:)]) {
			origValue.iconInsets = ALELibraryLayoutInsets(origValue.iconInsets);
		}
		if ([origValue respondsToSelector:@selector(setIconSpacing:)]) {
			CGSize spacing = origValue.iconSpacing;
			CGFloat width = ALELibraryIconListWidth(self);
			CGFloat horizontalInset = ALEIsLandscape() ? 72 : 48;
			CGFloat iconWidth = 74;
			spacing.width = MAX(spacing.width, (width - horizontalInset * 2 - iconWidth * columns) / MAX((CGFloat)(columns - 1), 1));
			origValue.iconSpacing = spacing;
		}
	}

	return origValue;
}
- (CGRect)frame {
	CGRect origValue = %orig;
	CGRect newContainerFrame = origValue;
	if (ALEIsLibraryIconList(self) && !ALEIsLibraryPodPreviewList(self)) {
		newContainerFrame.size.width = ALELibraryIconListWidth(self);
	}
	return newContainerFrame;
}
- (CGRect)iconLayoutRect {
	CGRect origValue = %orig;
	CGRect newFrame = origValue;
	if (ALEIsLibraryIconList(self) && !ALEIsLibraryPodPreviewList(self)) {
		newFrame.origin.x = 0;
		newFrame.size.width = ALELibraryIconListWidth(self);
	}
	return newFrame;
}

- (CGSize)iconSpacing {
	CGSize origValue = %orig;
	if (ALEIsLibraryIconList(self) && !ALEIsLibraryPodPreviewList(self)) {
		CGFloat width = ALELibraryIconListWidth(self);
		NSUInteger columns = ALELibraryColumnCount();
		CGFloat horizontalInset = ALEIsLandscape() ? 72 : 48;
		CGFloat iconWidth = 74;
		origValue.width = MAX(origValue.width, (width - horizontalInset * 2 - iconWidth * columns) / MAX((CGFloat)(columns - 1), 1));
	}
	return origValue;
}
- (CGSize)effectiveIconSpacing {
	CGSize origValue = %orig;
	if (ALEIsLibraryIconList(self) && !ALEIsLibraryPodPreviewList(self)) {
		CGFloat width = ALELibraryIconListWidth(self);
		NSUInteger columns = ALELibraryColumnCount();
		CGFloat horizontalInset = ALEIsLandscape() ? 72 : 48;
		CGFloat iconWidth = 74;
		origValue.width = MAX(origValue.width, (width - horizontalInset * 2 - iconWidth * columns) / MAX((CGFloat)(columns - 1), 1));
	}
	return origValue;
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
