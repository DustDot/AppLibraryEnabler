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

@interface SBHAppLibraryVisualConfiguration : NSObject
@property (nonatomic) CGSize expandedCategoryPodIconSpacing;
@property (nonatomic) CGSize landscapeCategoryPodIconSpacing;
@property (nonatomic) CGSize portraitCategoryPodIconSpacing;
@property (nonatomic) double searchContinuousCornerRadius;
@property (nonatomic) bool usesInsetPlatterSearchAppearance;
@end

@interface SBIconListGridLayoutConfiguration : NSObject
@property (nonatomic, copy) SBHAppLibraryVisualConfiguration *appLibraryVisualConfiguration;
@property (nonatomic) UIEdgeInsets landscapeLayoutInsets;
@property (nonatomic) CGSize listSizeForIconSpacingCalculation;
@property (nonatomic) unsigned long long numberOfLandscapeColumns;
@property (nonatomic) unsigned long long numberOfLandscapeRows;
@property (nonatomic) unsigned long long numberOfPortraitColumns;
@property (nonatomic) unsigned long long numberOfPortraitRows;
@property (nonatomic) UIEdgeInsets portraitLayoutInsets;
@end

static BOOL ALEObjectIsKindOfClassNamed(id object, const char *className) {
	if (!object || !className) {
		return NO;
	}

	Class cls = objc_getClass(className);
	if (cls) {
		return [object isKindOfClass:cls];
	}

	NSString *targetClassName = [NSString stringWithUTF8String:className];
	for (Class currentClass = object_getClass(object); currentClass; currentClass = class_getSuperclass(currentClass)) {
		if ([NSStringFromClass(currentClass) isEqualToString:targetClassName]) {
			return YES;
		}
	}

	return NO;
}

static BOOL ALEGridConfigurationHasAppLibraryVisualConfiguration(SBIconListGridLayoutConfiguration *configuration) {
	if (![configuration respondsToSelector:@selector(appLibraryVisualConfiguration)]) {
		return NO;
	}

	id visualConfiguration = configuration.appLibraryVisualConfiguration;
	return ALEObjectIsKindOfClassNamed(visualConfiguration, "SBHAppLibraryVisualConfiguration");
}

static BOOL ALEIsLandscapeInterface(void) {
	CGSize size = [UIScreen mainScreen].bounds.size;
	return size.width > size.height;
}

static CGSize ALEAppLibraryContentSizeForSpacing(void) {
	CGSize size = [UIScreen mainScreen].bounds.size;
	CGFloat width = MAX(size.width, size.height);
	CGFloat height = MIN(size.width, size.height);
	if (!ALEIsLandscapeInterface()) {
		width = MIN(size.width, size.height);
		height = MAX(size.width, size.height);
	}

	return CGSizeMake(floor(width * (ALEIsLandscapeInterface() ? 0.66 : 0.64)), floor(height * 0.58));
}

static void ALEConfigureAppLibraryVisualConfiguration(SBHAppLibraryVisualConfiguration *configuration) {
	if (!configuration) {
		return;
	}

	if ([configuration respondsToSelector:@selector(setLandscapeCategoryPodIconSpacing:)]) {
		configuration.landscapeCategoryPodIconSpacing = CGSizeMake(33.0, 37.0);
	}
	if ([configuration respondsToSelector:@selector(setPortraitCategoryPodIconSpacing:)]) {
		configuration.portraitCategoryPodIconSpacing = CGSizeMake(27.0, 31.0);
	}
	if ([configuration respondsToSelector:@selector(setExpandedCategoryPodIconSpacing:)]) {
		configuration.expandedCategoryPodIconSpacing = CGSizeMake(30.0, 30.0);
	}
	if ([configuration respondsToSelector:@selector(setSearchContinuousCornerRadius:)]) {
		configuration.searchContinuousCornerRadius = 18.0;
	}
	if ([configuration respondsToSelector:@selector(setUsesInsetPlatterSearchAppearance:)]) {
		configuration.usesInsetPlatterSearchAppearance = YES;
	}
}

static void ALEConfigureAppLibraryGridConfiguration(SBIconListGridLayoutConfiguration *configuration) {
	if (!ALEGridConfigurationHasAppLibraryVisualConfiguration(configuration)) {
		return;
	}

	ALEConfigureAppLibraryVisualConfiguration(configuration.appLibraryVisualConfiguration);

	if ([configuration respondsToSelector:@selector(setNumberOfLandscapeColumns:)]) {
		configuration.numberOfLandscapeColumns = 4;
	}
	if ([configuration respondsToSelector:@selector(setNumberOfLandscapeRows:)]) {
		configuration.numberOfLandscapeRows = 3;
	}
	if ([configuration respondsToSelector:@selector(setNumberOfPortraitColumns:)]) {
		configuration.numberOfPortraitColumns = 4;
	}
	if ([configuration respondsToSelector:@selector(setNumberOfPortraitRows:)]) {
		configuration.numberOfPortraitRows = 3;
	}
	if ([configuration respondsToSelector:@selector(setLandscapeLayoutInsets:)]) {
		configuration.landscapeLayoutInsets = UIEdgeInsetsMake(0.0, 0.0, 0.0, 0.0);
	}
	if ([configuration respondsToSelector:@selector(setPortraitLayoutInsets:)]) {
		configuration.portraitLayoutInsets = UIEdgeInsetsMake(0.0, 0.0, 0.0, 0.0);
	}
	if ([configuration respondsToSelector:@selector(setListSizeForIconSpacingCalculation:)]) {
		configuration.listSizeForIconSpacingCalculation = ALEAppLibraryContentSizeForSpacing();
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

%group iPadOS15AppLibraryConfiguration

%hook SBHAppLibraryVisualConfiguration
- (id)init {
	id result = %orig;
	ALEConfigureAppLibraryVisualConfiguration(result);
	return result;
}

- (CGSize)landscapeCategoryPodIconSpacing {
	return CGSizeMake(33.0, 37.0);
}

- (CGSize)portraitCategoryPodIconSpacing {
	return CGSizeMake(27.0, 31.0);
}

- (CGSize)expandedCategoryPodIconSpacing {
	return CGSizeMake(30.0, 30.0);
}

- (double)searchContinuousCornerRadius {
	return 18.0;
}

- (bool)usesInsetPlatterSearchAppearance {
	return YES;
}
%end

%hook SBIconListGridLayoutConfiguration
- (void)setAppLibraryVisualConfiguration:(SBHAppLibraryVisualConfiguration *)appLibraryVisualConfiguration {
	%orig;
	ALEConfigureAppLibraryGridConfiguration(self);
}

- (SBHAppLibraryVisualConfiguration *)appLibraryVisualConfiguration {
	SBHAppLibraryVisualConfiguration *configuration = %orig;
	ALEConfigureAppLibraryVisualConfiguration(configuration);
	return configuration;
}

- (unsigned long long)numberOfLandscapeColumns {
	if (ALEGridConfigurationHasAppLibraryVisualConfiguration(self)) {
		return 4;
	}
	return %orig;
}

- (unsigned long long)numberOfLandscapeRows {
	if (ALEGridConfigurationHasAppLibraryVisualConfiguration(self)) {
		return 3;
	}
	return %orig;
}

- (unsigned long long)numberOfPortraitColumns {
	if (ALEGridConfigurationHasAppLibraryVisualConfiguration(self)) {
		return 4;
	}
	return %orig;
}

- (unsigned long long)numberOfPortraitRows {
	if (ALEGridConfigurationHasAppLibraryVisualConfiguration(self)) {
		return 3;
	}
	return %orig;
}

- (UIEdgeInsets)landscapeLayoutInsets {
	if (ALEGridConfigurationHasAppLibraryVisualConfiguration(self)) {
		return UIEdgeInsetsZero;
	}
	return %orig;
}

- (UIEdgeInsets)portraitLayoutInsets {
	if (ALEGridConfigurationHasAppLibraryVisualConfiguration(self)) {
		return UIEdgeInsetsZero;
	}
	return %orig;
}

- (CGSize)listSizeForIconSpacingCalculation {
	if (ALEGridConfigurationHasAppLibraryVisualConfiguration(self)) {
		return ALEAppLibraryContentSizeForSpacing();
	}
	return %orig;
}
%end

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
	if (objc_getClass("SBHAppLibraryVisualConfiguration") && objc_getClass("SBIconListGridLayoutConfiguration")) {
		%init(iPadOS15AppLibraryConfiguration);
	}
}
