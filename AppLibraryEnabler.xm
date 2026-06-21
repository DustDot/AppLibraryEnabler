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
@property (nonatomic,readonly) id currentIconListView;
@end

@interface SBIconListModel : NSObject
@property (nonatomic, readonly) id folder;
@end

@interface SBIconListView : UIView
@property (nonatomic, readonly) SBIconListModel *model;
@property (nonatomic, readonly, copy) NSArray *icons;
- (id)iconViewForIcon:(id)icon;
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

	id avocadoViewController = ALEValueForKey(controller, @"avocadoViewController");
	if (avocadoViewController && avocadoViewController != controller) {
		return ALEIsLibraryController(avocadoViewController);
	}

	id contentViewController = ALEValueForKey(controller, @"contentViewController");
	if (contentViewController && contentViewController != controller) {
		return ALEIsLibraryController(contentViewController);
	}

	return NO;
}

static BOOL ALEOverlayShowsAppLibrary(SBHomeScreenOverlayViewController *overlayController) {
	id rightSidebarViewController = ALEValueForKey(overlayController, @"rightSidebarViewController");
	id contentViewController = ALEValueForKey(overlayController, @"contentViewController");
	return ALEIsLibraryController(rightSidebarViewController) || ALEIsLibraryController(contentViewController);
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

static BOOL ALEIsLibraryCategoriesRootListView(SBIconListView *listView) {
	if (![listView isKindOfClass:[UIView class]]) {
		return NO;
	}

	SBIconListModel *model = nil;
	if ([listView respondsToSelector:@selector(model)]) {
		model = [listView model];
	}
	if (!model) {
		model = ALEValueForKey(listView, @"model");
	}

	id folder = nil;
	if ([model respondsToSelector:@selector(folder)]) {
		folder = [model folder];
	}
	if (!folder) {
		folder = ALEValueForKey(model, @"folder");
	}

	return ALEObjectIsKindOfClassNamed(folder, @"SBHLibraryCategoriesRootFolder");
}

static CGFloat ALELibraryRootContentWidth(CGFloat containerWidth) {
	if (containerWidth <= 0) {
		containerWidth = ALEInterfaceSize().width;
	}

	CGFloat widthRatio = ALEIsLandscape() ? 0.68 : 0.72;
	CGFloat maxContentWidth = ALEIsLandscape() ? 960.0 : 760.0;
	CGFloat minSideInset = ALEIsLandscape() ? 150.0 : 72.0;
	CGFloat contentWidth = floor(MIN(containerWidth - (minSideInset * 2.0), containerWidth * widthRatio));
	contentWidth = MIN(contentWidth, maxContentWidth);
	return MAX(contentWidth, containerWidth * 0.56);
}

static void ALELayoutLibraryCategoriesRootListView(SBIconListView *listView) {
	if (!ALEIsLibraryCategoriesRootListView(listView) ||
		![listView respondsToSelector:@selector(icons)] ||
		![listView respondsToSelector:@selector(iconViewForIcon:)]) {
		return;
	}

	NSArray *icons = listView.icons;
	if (![icons isKindOfClass:[NSArray class]] || icons.count == 0) {
		return;
	}

	UIView *containerView = listView.superview ?: listView;
	CGFloat containerWidth = CGRectGetWidth(containerView.bounds);
	if (containerWidth <= 0) {
		containerWidth = ALEInterfaceSize().width;
	}

	CGFloat contentWidth = ALELibraryRootContentWidth(containerWidth);
	CGRect listFrame = listView.frame;
	listFrame.origin.x = floor((containerWidth - contentWidth) / 2.0);
	listFrame.size.width = contentWidth;
	listView.frame = listFrame;

	NSUInteger columnCount = 4;
	CGFloat topY = CGFLOAT_MAX;
	CGFloat secondY = CGFLOAT_MAX;
	CGFloat podWidth = 0.0;
	CGFloat podHeight = 0.0;

	for (id icon in icons) {
		UIView *iconView = [listView iconViewForIcon:icon];
		if (![iconView isKindOfClass:[UIView class]] || iconView.hidden || iconView.alpha <= 0.01) {
			continue;
		}

		CGRect bounds = iconView.bounds;
		CGRect frame = iconView.frame;
		CGFloat width = CGRectGetWidth(bounds) > 0 ? CGRectGetWidth(bounds) : CGRectGetWidth(frame);
		CGFloat height = CGRectGetHeight(bounds) > 0 ? CGRectGetHeight(bounds) : CGRectGetHeight(frame);
		if (width <= 0 || height <= 0) {
			continue;
		}

		podWidth = MAX(podWidth, width);
		podHeight = MAX(podHeight, height);

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

	CGFloat columnGap = ALEIsLandscape() ? 48.0 : 28.0;
	CGFloat desiredPodWidth = floor((contentWidth - (columnGap * (columnCount - 1))) / columnCount);
	CGFloat scale = MIN((CGFloat)1.0, desiredPodWidth / podWidth);
	scale = MAX(scale, ALEIsLandscape() ? (CGFloat)0.72 : (CGFloat)0.58);
	CGFloat scaledPodWidth = floor(podWidth * scale);
	CGFloat scaledPodHeight = floor(podHeight * scale);
	CGFloat usedWidth = (scaledPodWidth * columnCount) + (columnGap * (columnCount - 1));
	CGFloat leftInset = floor((contentWidth - usedWidth) / 2.0);
	CGFloat rowStep = secondY != CGFLOAT_MAX ? secondY - topY : scaledPodHeight + 38.0;
	rowStep = MAX(rowStep * scale, scaledPodHeight + (ALEIsLandscape() ? 34.0 : 26.0));

	for (NSUInteger iconIndex = 0; iconIndex < icons.count; iconIndex++) {
		UIView *iconView = [listView iconViewForIcon:icons[iconIndex]];
		if (![iconView isKindOfClass:[UIView class]] || iconView.hidden || iconView.alpha <= 0.01) {
			continue;
		}

		NSUInteger column = iconIndex % columnCount;
		NSUInteger row = iconIndex / columnCount;
		iconView.transform = CGAffineTransformMakeScale(scale, scale);
		iconView.center = CGPointMake(
			leftInset + (scaledPodWidth / 2.0) + ((scaledPodWidth + columnGap) * column),
			topY + (scaledPodHeight / 2.0) + (rowStep * row)
		);
	}
}

static void ALELayoutLibraryCategoriesRootController(SBHLibraryPodFolderController *controller) {
	if (![controller isKindOfClass:[UIViewController class]]) {
		return;
	}

	id listView = nil;
	if ([controller respondsToSelector:@selector(currentIconListView)]) {
		listView = [controller currentIconListView];
	}
	if (!listView) {
		listView = ALEValueForKey(controller, @"currentIconListView");
	}

	ALELayoutLibraryCategoriesRootListView((SBIconListView *)listView);
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
		CGFloat width = ALEInterfaceSize().width;
		if (width > 0) {
			return width;
		}
	}
	return %orig;
}

-(CGFloat)contentWidthWithContainerWidth:(CGFloat)containerWidth {
	if (ALEOverlayShowsAppLibrary(self) && containerWidth > 0) {
		return containerWidth;
	}
	return %orig;
}

-(CGFloat)presentationProgress {
	CGFloat origValue = %orig;
	[[self rightSidebarViewController].view setAlpha:origValue];
	return origValue;
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
- (void)viewDidLayoutSubviews {
	%orig;
	ALELayoutLibraryCategoriesRootController(self);
}

- (void)viewWillAppear:(bool)arg1 {
	%orig;
	ALELayoutLibraryCategoriesRootController(self);
}

- (void)viewDidAppear:(bool)arg1 {
	%orig;
	UIView *containerView = [self containerView];
	CGRect containerFrame = containerView.frame;
	[self.view setFrame:containerFrame];
	ALELayoutLibraryCategoriesRootController(self);
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
