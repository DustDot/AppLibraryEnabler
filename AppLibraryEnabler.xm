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
	if (cls) {
		return [object isKindOfClass:cls];
	}

	for (Class currentClass = object_getClass(object); currentClass; currentClass = class_getSuperclass(currentClass)) {
		if ([NSStringFromClass(currentClass) isEqualToString:className]) {
			return YES;
		}
	}

	return NO;
}

static BOOL ALEIsLibraryController(id controller) {
	if (!controller) {
		return NO;
	}

	if (ALEObjectIsKindOfClassNamed(controller, @"SBHLibraryViewController") ||
		ALEObjectIsKindOfClassNamed(controller, @"SBHLibrarySearchController") ||
		ALEObjectIsKindOfClassNamed(controller, @"SBHLibraryPodFolderController")) {
		return YES;
	}

	id childController = ALEValueForKey(controller, @"contentViewController");
	if (childController && childController != controller && ALEIsLibraryController(childController)) {
		return YES;
	}

	childController = ALEValueForKey(controller, @"avocadoViewController");
	if (childController && childController != controller && ALEIsLibraryController(childController)) {
		return YES;
	}

	return NO;
}

static CGSize ALEInterfaceSize(void) {
	UIWindow *keyWindow = ALEValueForKey([UIApplication sharedApplication], @"keyWindow");
	if ([keyWindow isKindOfClass:[UIWindow class]] && !CGSizeEqualToSize(keyWindow.bounds.size, CGSizeZero)) {
		return keyWindow.bounds.size;
	}

	return [UIScreen mainScreen].bounds.size;
}

static BOOL ALEIsLandscape(void) {
	CGSize size = ALEInterfaceSize();
	return size.width > size.height;
}

static CGRect ALELibraryFullScreenFrame(void) {
	CGSize size = ALEInterfaceSize();
	return CGRectMake(0.0, 0.0, size.width, size.height);
}

static BOOL ALEOverlayShowsAppLibrary(SBHomeScreenOverlayViewController *overlayController) {
	id rightSidebarViewController = ALEValueForKey(overlayController, @"rightSidebarViewController");
	id contentViewController = ALEValueForKey(overlayController, @"contentViewController");
	return ALEIsLibraryController(rightSidebarViewController) || ALEIsLibraryController(contentViewController);
}

static void ALEExpandLibraryControllerView(UIViewController *controller) {
	if (!ALEIsLibraryController(controller) || ![controller.view isKindOfClass:[UIView class]]) {
		return;
	}

	CGRect fullScreenFrame = ALELibraryFullScreenFrame();
	controller.view.frame = fullScreenFrame;
	controller.view.bounds = fullScreenFrame;
	controller.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
}

static CGFloat ALELibraryPodWidth(void) {
	CGFloat width = ALEInterfaceSize().width;
	CGFloat contentWidth = floor(MIN(width * (ALEIsLandscape() ? 0.68 : 0.74), ALEIsLandscape() ? 980.0 : 700.0));
	CGFloat gap = ALEIsLandscape() ? 48.0 : 28.0;
	return floor((contentWidth - (gap * 3.0)) / 4.0);
}

static CGSize ALELibraryPodSpacing(CGSize originalSpacing) {
	CGSize spacing = originalSpacing;
	spacing.width = ALEIsLandscape() ? 24.0 : 18.0;
	spacing.height = ALEIsLandscape() ? 28.0 : 22.0;
	return spacing;
}

static CGRect ALELibrarySearchBarFrame(CGRect frame) {
	CGSize interfaceSize = ALEInterfaceSize();
	CGFloat targetWidth = floor(MIN(interfaceSize.width * (ALEIsLandscape() ? 0.32 : 0.42), ALEIsLandscape() ? 450.0 : 340.0));
	if (targetWidth <= 0 || interfaceSize.width <= 0) {
		return frame;
	}

	frame.origin.x = floor((interfaceSize.width - targetWidth) / 2.0);
	frame.origin.y = floor(interfaceSize.height * (ALEIsLandscape() ? 0.070 : 0.190));
	frame.size.width = targetWidth;
	frame.size.height = MAX((CGFloat)44.0, frame.size.height);
	return frame;
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
		return ALEInterfaceSize().width;
	}
	return %orig;
}

-(CGFloat)contentWidthWithContainerWidth:(CGFloat)containerWidth {
	if (ALEOverlayShowsAppLibrary(self)) {
		return containerWidth > 0.0 ? containerWidth : ALEInterfaceSize().width;
	}
	return %orig;
}

-(void)viewDidLayoutSubviews {
	%orig;
	if (ALEOverlayShowsAppLibrary(self)) {
		ALEExpandLibraryControllerView((UIViewController *)ALEValueForKey(self, @"rightSidebarViewController"));
	}
}

-(CGFloat)presentationProgress {
	CGFloat origValue = %orig;
	UIViewController *rightSidebarViewController = [self rightSidebarViewController];
	if (ALEOverlayShowsAppLibrary(self)) {
		ALEExpandLibraryControllerView(rightSidebarViewController);
	}
	[rightSidebarViewController.view setAlpha:origValue];
	return origValue;
}
%end

%hook SBHLibrarySearchController
- (void)viewDidLayoutSubviews {
	%orig;
	SBHSearchBar *searchBar = ALEValueForKey(self, @"_searchBar");
	UIView *containerView = ALEValueForKey(self, @"_containerView");
	UIView *contentContainerView = ALEValueForKey(self, @"_contentContainerView");
	UIView *searchResultsContainerView = ALEValueForKey(self, @"_searchResultsContainerView");
	CGRect selfFrame = self.view.bounds;

	[containerView setFrame:selfFrame];
	[contentContainerView setFrame:selfFrame];
	[searchResultsContainerView setFrame:selfFrame];

	if ([searchBar isKindOfClass:[UIView class]]) {
		[searchBar setFrame:ALELibrarySearchBarFrame(searchBar.frame)];
	}
}

- (void)viewDidAppear:(bool)arg1 {
	%orig;
	SBHSearchBar *searchBar = ALEValueForKey(self, @"_searchBar");
	UIView *containerView = ALEValueForKey(self, @"_containerView");
	UIView *contentContainerView = ALEValueForKey(self, @"_contentContainerView");
	UIView *searchResultsContainerView = ALEValueForKey(self, @"_searchResultsContainerView");

	CGRect selfFrame = self.view.bounds;
	[containerView setFrame:selfFrame];
	[contentContainerView setFrame:selfFrame];
	[searchResultsContainerView setFrame:selfFrame];

	if ([searchBar respondsToSelector:@selector(searchTextFieldHorizontalEdgeInsets)] &&
		[searchBar respondsToSelector:@selector(setSearchTextFieldHorizontalEdgeInsets:)]) {
		UIEdgeInsets searchTextFieldHorizontalEdgeInsets = [searchBar searchTextFieldHorizontalEdgeInsets];
		searchTextFieldHorizontalEdgeInsets.left = 23;
		searchTextFieldHorizontalEdgeInsets.right = 23;
		[searchBar setSearchTextFieldHorizontalEdgeInsets:searchTextFieldHorizontalEdgeInsets];
	}

	if ([searchBar isKindOfClass:[UIView class]]) {
		[searchBar setFrame:ALELibrarySearchBarFrame(searchBar.frame)];
	}
}
- (void)_layoutSearchViews {
	%orig;
	MTMaterialView *searchBackdropView = ALEValueForKey(self, @"_searchBackdropView");

	CGFloat width = ALEInterfaceSize().width;
	CGFloat height = ALEInterfaceSize().height;

	CGRect fullScreenFrame = CGRectMake(
		-100,
		-100,
		width + 200,
		height + 200
	);
	[searchBackdropView setBounds:fullScreenFrame];
	[searchBackdropView setFrame:fullScreenFrame];

	SBHSearchBar *searchBar = ALEValueForKey(self, @"_searchBar");
	if ([searchBar isKindOfClass:[UIView class]]) {
		[searchBar setFrame:ALELibrarySearchBarFrame(searchBar.frame)];
	}
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
	newContainerFrame.size.width = ALELibraryPodWidth();
	return newContainerFrame;
}
- (CGRect)iconLayoutRect {
	CGRect origValue = %orig;
	CGRect newFrame = origValue;
	newFrame.size.width = ALELibraryPodWidth();
	return newFrame;
}

- (CGSize)iconSpacing {
	CGSize origValue = %orig;
	return ALELibraryPodSpacing(origValue);
}
- (CGSize)effectiveIconSpacing {
	CGSize origValue = %orig;
	return ALELibraryPodSpacing(origValue);
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
