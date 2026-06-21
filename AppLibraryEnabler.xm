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

@interface SBIconListGridLayout : NSObject
@property (nonatomic, copy, readonly) SBIconListGridLayoutConfiguration *layoutConfiguration;
- (unsigned long long)numberOfColumnsForOrientation:(long long)orientation;
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
- (struct SBHIconGridSize)gridSize;
- (id)gridCellInfoForGridSize:(struct SBHIconGridSize)gridSize options:(unsigned long long)options;
@end

static BOOL ALEConfiguringLibraryRootLayout = NO;
static char ALEAppLibraryRootLayoutKey;

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

static BOOL ALEObjectsEqual(id firstObject, id secondObject) {
	if (firstObject == secondObject) {
		return YES;
	}
	if (!firstObject || !secondObject || ![firstObject respondsToSelector:@selector(isEqual:)]) {
		return NO;
	}

	return [firstObject isEqual:secondObject];
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
	if ([keyWindow isKindOfClass:[UIWindow class]] && !CGSizeEqualToSize(keyWindow.bounds.size, CGSizeZero)) {
		return keyWindow.bounds.size;
	}

	return [UIScreen mainScreen].bounds.size;
}

static BOOL ALEIsLandscapeScreen(void) {
	NSNumber *orientationValue = ALEValueForKey([UIApplication sharedApplication], @"statusBarOrientation");
	if ([orientationValue isKindOfClass:[NSNumber class]]) {
		UIInterfaceOrientation orientation = (UIInterfaceOrientation)[orientationValue integerValue];
		if (orientation != UIInterfaceOrientationUnknown) {
			return UIInterfaceOrientationIsLandscape(orientation);
		}
	}

	CGSize interfaceSize = ALECurrentInterfaceSize();
	return interfaceSize.width > interfaceSize.height;
}

static CGSize ALELayoutInterfaceSize(void) {
	CGSize interfaceSize = ALECurrentInterfaceSize();
	BOOL landscape = ALEIsLandscapeScreen();
	return CGSizeMake(
		landscape ? MAX(interfaceSize.width, interfaceSize.height) : MIN(interfaceSize.width, interfaceSize.height),
		landscape ? MIN(interfaceSize.width, interfaceSize.height) : MAX(interfaceSize.width, interfaceSize.height)
	);
}

static CGFloat ALELibraryRootContentWidth(CGFloat interfaceWidth) {
	BOOL landscape = ALEIsLandscapeScreen();
	CGFloat width = interfaceWidth * (landscape ? 0.72 : 0.86);
	CGFloat minimumWidth = landscape ? 1040.0 : 960.0;
	CGFloat maximumWidth = landscape ? 1320.0 : 1180.0;
	return MIN(MAX(width, minimumWidth), MIN(interfaceWidth, maximumWidth));
}

static struct SBHIconGridSize ALELibraryRootGridSize(struct SBHIconGridSize originalGridSize) {
	struct SBHIconGridSize gridSize = originalGridSize;
	gridSize.columns = MAX(gridSize.columns, (unsigned short)8);
	gridSize.rows = MAX(gridSize.rows, (unsigned short)(ALEIsLandscapeScreen() ? 8 : 10));
	return gridSize;
}

static void ALEConfigureAppLibraryRootGrid(SBIconListGridLayoutConfiguration *configuration) {
	if (!configuration) {
		return;
	}

	CGSize screenSize = ALELayoutInterfaceSize();
	CGFloat interfaceWidth = screenSize.width;
	CGFloat interfaceHeight = screenSize.height;
	CGFloat rootContentWidth = ALELibraryRootContentWidth(interfaceWidth);

	if ([configuration respondsToSelector:@selector(setNumberOfLandscapeColumns:)]) {
		configuration.numberOfLandscapeColumns = 8;
	}
	if ([configuration respondsToSelector:@selector(setNumberOfLandscapeRows:)]) {
		configuration.numberOfLandscapeRows = 8;
	}
	if ([configuration respondsToSelector:@selector(setNumberOfPortraitColumns:)]) {
		configuration.numberOfPortraitColumns = 8;
	}
	if ([configuration respondsToSelector:@selector(setNumberOfPortraitRows:)]) {
		configuration.numberOfPortraitRows = 10;
	}
	if ([configuration respondsToSelector:@selector(setListSizeForIconSpacingCalculation:)]) {
		configuration.listSizeForIconSpacingCalculation = CGSizeMake(rootContentWidth, interfaceHeight);
	}
	if ([configuration respondsToSelector:@selector(setLandscapeLayoutInsets:)]) {
		UIEdgeInsets insets = configuration.landscapeLayoutInsets;
		insets.left = MAX((CGFloat)0.0, (interfaceWidth - rootContentWidth) / 2.0);
		insets.right = insets.left;
		configuration.landscapeLayoutInsets = insets;
	}
	if ([configuration respondsToSelector:@selector(setPortraitLayoutInsets:)]) {
		UIEdgeInsets insets = configuration.portraitLayoutInsets;
		insets.left = MAX((CGFloat)0.0, (interfaceWidth - rootContentWidth) / 2.0);
		insets.right = insets.left;
		configuration.portraitLayoutInsets = insets;
	}
}

static void ALEConfigureLayoutForLibraryRoot(id layout) {
	if (![layout respondsToSelector:@selector(layoutConfiguration)]) {
		return;
	}

	SBIconListGridLayoutConfiguration *configuration = [layout layoutConfiguration];
	ALEConfigureAppLibraryRootGrid(configuration);
	objc_setAssociatedObject(layout, &ALEAppLibraryRootLayoutKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
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
	if (ALEConfiguringLibraryRootLayout) {
		ALEConfigureAppLibraryRootGrid(configuration);
	}
}

- (id)makeLayoutForIconLocation:(id)iconLocation {
	BOOL previousRootLayout = ALEConfiguringLibraryRootLayout;
	ALEConfiguringLibraryRootLayout = ALEIsLibraryRootIconLocation(iconLocation);
	id layout = %orig;
	ALEConfiguringLibraryRootLayout = previousRootLayout;

	if (ALEIsLibraryRootIconLocation(iconLocation)) {
		ALEConfigureLayoutForLibraryRoot(layout);
	}
	return layout;
}

- (id)layoutForIconLocation:(id)iconLocation {
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

%hook SBIconListGridLayout
- (unsigned long long)numberOfColumnsForOrientation:(long long)orientation {
	unsigned long long origValue = %orig;
	if ([objc_getAssociatedObject(self, &ALEAppLibraryRootLayoutKey) boolValue]) {
		return MAX(origValue, (unsigned long long)8);
	}

	return origValue;
}
%end

%hook SBFolder
- (struct SBHIconGridSize)listGridSize {
	struct SBHIconGridSize gridSize = %orig;
	if (ALEIsLibraryCategoriesRootFolder(self)) {
		return ALELibraryRootGridSize(gridSize);
	}

	return gridSize;
}
%end

%hook SBIconListModel
- (struct SBHIconGridSize)gridSize {
	struct SBHIconGridSize gridSize = %orig;
	if (ALEIsLibraryCategoriesRootFolder(self.folder)) {
		return ALELibraryRootGridSize(gridSize);
	}

	return gridSize;
}

- (id)gridCellInfoForGridSize:(struct SBHIconGridSize)gridSize options:(unsigned long long)options {
	if (ALEIsLibraryCategoriesRootFolder(self.folder)) {
		return %orig(ALELibraryRootGridSize(gridSize), options);
	}

	return %orig;
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
