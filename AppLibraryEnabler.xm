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

static CGRect ALEFullFrameForView(UIView *view) {
	CGRect frame = view.bounds;

	if (CGRectGetWidth(view.superview.bounds) > CGRectGetWidth(frame)) {
		frame = view.superview.bounds;
	}

	if (CGRectGetWidth(view.window.bounds) > CGRectGetWidth(frame)) {
		frame = view.window.bounds;
	}

	if (CGRectGetWidth(frame) > 0 && CGRectGetHeight(frame) > 0) {
		frame.origin = CGPointZero;
		return frame;
	}

	CGSize screenSize = [UIScreen mainScreen].bounds.size;
	return CGRectMake(0, 0, screenSize.width, screenSize.height);
}

static void ALESetViewFrame(UIView *view, CGRect frame) {
	if (!view) {
		return;
	}

	view.frame = frame;
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

	CGRect fullFrame = ALEFullFrameForView(overlayController.view);
	UIViewController *rightSidebarViewController = ALEValueForKey(overlayController, @"rightSidebarViewController");
	UIViewController *contentViewController = ALEValueForKey(overlayController, @"contentViewController");

	ALESetViewFrame(rightSidebarViewController.view, fullFrame);
	ALESetViewFrame(contentViewController.view, fullFrame);

	UIViewController *avocadoViewController = ALEValueForKey(contentViewController, @"avocadoViewController");
	ALESetViewFrame(avocadoViewController.view, fullFrame);
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
	UIView *containerView = [self containerView];
	CGRect containerFrame = containerView.frame;
	[self.view setFrame:containerFrame];
}
%end

%hook _SBHLibraryPodIconListView
- (CGRect)frame {
	CGRect origValue = %orig;
	CGRect newContainerFrame = origValue;
	newContainerFrame.size.width = 393;
	return newContainerFrame;
}
- (CGRect)iconLayoutRect {
	CGRect origValue = %orig;
	CGRect newFrame = origValue;
	newFrame.size.width = 393;
	return newFrame;
}

- (CGSize)iconSpacing {
	CGSize origValue = %orig;
	CGSize newSize = origValue;
	newSize.width = 33;
	newSize.height = 37;
	return newSize;
}
- (CGSize)effectiveIconSpacing {
	CGSize origValue = %orig;
	CGSize newSize = origValue;
	newSize.width = 33;
	newSize.height = 37;
	return newSize;
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
