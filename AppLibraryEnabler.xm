#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface SBHLibraryPodFolderController : NSObject
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
@end

@interface SBIconListGridLayout : NSObject
@property (nonatomic, copy, readonly) SBIconListGridLayoutConfiguration *layoutConfiguration;
@end

@interface SBFolder : NSObject
- (struct SBHIconGridSize)listGridSize;
@end

@interface SBIconListModel : NSObject
@property (nonatomic, readonly) SBFolder *folder;
- (struct SBHIconGridSize)gridSize;
- (id)gridCellInfoForGridSize:(struct SBHIconGridSize)gridSize options:(unsigned long long)options;
@end

static BOOL ALEConfiguringLibraryRootLayout = NO;

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

static CGFloat ALELibraryRootContentWidth(CGFloat interfaceWidth) {
	CGFloat width = interfaceWidth * (ALEIsLandscapeScreen() ? 0.66 : 0.64);
	CGFloat minimumWidth = ALEIsLandscapeScreen() ? 820.0 : 600.0;
	CGFloat maximumWidth = ALEIsLandscapeScreen() ? 1040.0 : 760.0;
	return MIN(MAX(width, minimumWidth), MIN(interfaceWidth, maximumWidth));
}

static void ALEConfigureAppLibraryGrid(SBIconListGridLayoutConfiguration *configuration, BOOL rootLayout) {
	if (!configuration) {
		return;
	}

	CGSize screenSize = ALECurrentInterfaceSize();
	CGFloat interfaceWidth = screenSize.width;
	CGFloat interfaceHeight = screenSize.height;
	CGFloat rootContentWidth = ALELibraryRootContentWidth(interfaceWidth);
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
		insets.left = rootLayout ? MAX((CGFloat)0, (interfaceWidth - rootContentWidth) / 2.0) : MAX((CGFloat)96.0, interfaceWidth * 0.11);
		insets.right = insets.left;
		configuration.landscapeLayoutInsets = insets;
	}
	if ([configuration respondsToSelector:@selector(setPortraitLayoutInsets:)]) {
		UIEdgeInsets insets = configuration.portraitLayoutInsets;
		insets.left = rootLayout ? MAX((CGFloat)0, (interfaceWidth - rootContentWidth) / 2.0) : MAX((CGFloat)72.0, interfaceWidth * 0.105);
		insets.right = insets.left;
		configuration.portraitLayoutInsets = insets;
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
		return %orig(rootGridSize, options);
	}

	return %orig;
}
%end

%ctor {
	%init;
}
