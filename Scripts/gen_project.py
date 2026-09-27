#!/usr/bin/env python3
"""Generates Blob.xcodeproj/project.pbxproj deterministically."""
import hashlib, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

FILES = [
    ("BlobApp.swift", "Sources"),
    ("Blobatar/Blobatar.swift", "Sources"),
    ("Blobatar/BlobatarView.swift", "Sources"),
    ("Blobatar/SilhouetteShapes.swift", "Sources"),
    ("Audio/AudioLevelMeter.swift", "Sources"),
    ("Audio/SpeechEngine.swift", "Sources"),
    ("Audio/SpeakerSegmenter.swift", "Sources"),
    ("Intelligence/Summary.swift", "Sources"),
    ("Intelligence/TodoExtractor.swift", "Sources"),
    ("Intelligence/LocalSummarizer.swift", "Sources"),
    ("Intelligence/MistralSummarizer.swift", "Sources"),
    ("UI/MainView.swift", "Sources"),
    ("UI/TranscriptView.swift", "Sources"),
    ("UI/SummaryPanel.swift", "Sources"),
]

def fid(path):
    return hashlib.md5(("blob" + path).encode()).hexdigest()[:24].upper()

def main():
    proj_dir = os.path.join(ROOT, "Blob.xcodeproj")
    os.makedirs(proj_dir, exist_ok=True)

    file_refs = []
    build_files = []
    for rel, _ in FILES:
        ref = fid("ref:" + rel)
        build = fid("build:" + rel)
        file_refs.append((ref, rel, os.path.basename(rel)))
        build_files.append((build, ref, os.path.basename(rel)))

    infoplist = fid("ref:Info.plist")
    assets = fid("ref:Assets.xcassets")

    lines = []
    lines.append("// !$*UTF8*$!\n{")
    lines.append("\tarchiveVersion = 1;")
    lines.append("\tobjectVersion = 56;")
    lines.append("\tclasses = {};")
    lines.append("\tobjects = {")
    lines.append("")
    lines.append("/* Begin PBXFileReference section */")
    for ref, rel, base in file_refs:
        lines.append(f"\t\t{ref} /* {base} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; name = {base}; path = {rel}; sourceTree = \"<group>\"; }};")
    lines.append(f"\t\t{infoplist} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; name = Info.plist; path = Info.plist; sourceTree = \"<group>\"; }};")
    lines.append(f"\t\t{assets} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; name = Assets.xcassets; path = Assets.xcassets; sourceTree = \"<group>\"; }};")
    lines.append("/* End PBXFileReference section */")
    lines.append("")
    lines.append("/* Begin PBXBuildFile section */")
    for build, ref, base in build_files:
        lines.append(f"\t\t{build} /* {base} in Sources */ = {{isa = PBXBuildFile; fileRef = {ref} /* {base} */; }};")
    lines.append(f"\t\t{fid('build:Assets')} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {assets} /* Assets.xcassets */; }};")
    lines.append("/* End PBXBuildFile section */")
    lines.append("")
    lines.append("/* Begin PBXGroup section */")
    def mkgroup(gid, name, kid_ids):
        lines.append(f"\t\t{gid} = {{isa = PBXGroup; children = ({', '.join(kid_ids)}); name = {name}; sourceTree = \"<group>\"; }};")
    mkgroup(fid("grp:Blobatar"), "Blobatar", [fid("ref:Blobatar/Blobatar.swift"), fid("ref:Blobatar/BlobatarView.swift"), fid("ref:Blobatar/SilhouetteShapes.swift")])
    mkgroup(fid("grp:Audio"), "Audio", [fid("ref:Audio/AudioLevelMeter.swift"), fid("ref:Audio/SpeechEngine.swift"), fid("ref:Audio/SpeakerSegmenter.swift")])
    mkgroup(fid("grp:Intelligence"), "Intelligence", [fid("ref:Intelligence/Summary.swift"), fid("ref:Intelligence/TodoExtractor.swift"), fid("ref:Intelligence/LocalSummarizer.swift"), fid("ref:Intelligence/MistralSummarizer.swift")])
    mkgroup(fid("grp:UI"), "UI", [fid("ref:UI/MainView.swift"), fid("ref:UI/TranscriptView.swift"), fid("ref:UI/SummaryPanel.swift")])
    main_kids = [fid("ref:BlobApp.swift"), fid("grp:Blobatar"), fid("grp:Audio"), fid("grp:Intelligence"), fid("grp:UI"), assets, infoplist]
    mkgroup(fid("grp:Main"), "Blob", main_kids)
    mkgroup(fid("grp:Root"), "", [fid("grp:Main")])
    lines.append("/* End PBXGroup section */")
    lines.append("")
    lines.append("/* Begin PBXNativeTarget section */")
    lines.append(f"\t\t{fid('target:Blob')} /* Blob */ = {{isa = PBXNativeTarget; buildConfigurationList = {fid('xcconfiglist:target')} /* Build configuration list for PBXNativeTarget \"Blob\" */; buildPhases = ({fid('sources:Blob')} /* Sources */, {fid('resources:Blob')} /* Resources */); buildRules = (); dependencies = (); name = Blob; productName = Blob; productReference = {fid('ref:Blob.app')} /* Blob.app */; productType = \"com.apple.product-type.application\"; }};")
    lines.append("/* End PBXNativeTarget section */")
    lines.append("")
    lines.append("/* Begin PBXProject section */")
    lines.append(f"\t\t{fid('project')} /* Project object */ = {{isa = PBXProject; attributes = {{BuildIndependentTargetsInParallel = 1; LastSwiftUpdateCheck = 1500; LastUpgradeCheck = 1500;}}; buildConfigurationList = {fid('xcconfiglist:project')} /* Build configuration list for PBXProject \"Blob\" */; compatibilityVersion = \"Xcode 14.0\"; developmentRegion = es; hasScannedForEncodings = 0; knownRegions = (es, en, Base); mainGroup = {fid('grp:Root')}; productRefGroup = {fid('grp:Products')} /* Products */; projectDirPath = \"\"; projectRoot = \"\"; targets = ({fid('target:Blob')} /* Blob */); }};")
    lines.append("/* End PBXProject section */")
    lines.append("")
    lines.append("/* Begin PBXResourcesBuildPhase section */")
    lines.append(f"\t\t{fid('resources:Blob')} /* Resources */ = {{isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ({fid('build:Assets')} /* Assets.xcassets in Resources */); runOnlyForDeploymentPostprocessing = 0; }};")
    lines.append("/* End PBXResourcesBuildPhase section */")
    lines.append("")
    lines.append("/* Begin PBXSourcesBuildPhase section */")
    src_files = ", ".join(f"{b} /* {n} in Sources */" for b, _, n in build_files)
    lines.append(f"\t\t{fid('sources:Blob')} /* Sources */ = {{isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({src_files}); runOnlyForDeploymentPostprocessing = 0; }};")
    lines.append("/* End PBXSourcesBuildPhase section */")
    lines.append("")
    lines.append("/* Begin PBXVariantGroup section */")
    lines.append("/* End PBXVariantGroup section */")
    lines.append("")
    lines.append("/* Begin XCBuildConfiguration section */")
    def xcconfig(gid, name, settings_lines):
        lines.append(f"\t\t{gid} /* {name} */ = {{isa = XCBuildConfiguration; buildSettings = {{")
        for k, v in settings_lines:
            lines.append(f"\t\t\t\t{k} = {v};")
        lines.append("\t\t\t}; name = %s; };" % name)
    base = [
        ("ALWAYS_SEARCH_USER_PATHS", "NO"),
        ("CLANG_ENABLE_MODULES", "YES"),
        ("COPY_PHASE_STRIP", "NO"),
        ("DEBUG_INFORMATION_FORMAT", "\"dwarf-with-dsym\""),
        ("ENABLE_STRICT_OBJC_MSGSEND", "YES"),
        ("GCC_C_LANGUAGE_STANDARD", "gnu17"),
        ("GCC_NO_COMMON_BLOCKS", "YES"),
        ("MACOSX_DEPLOYMENT_TARGET", "13.0"),
        ("SDKROOT", "macosx"),
        ("SWIFT_VERSION", "5.9"),
        ("SWIFT_OPTIMIZATION_LEVEL", "-Onone"),
    ]
    proj_debug = base + [("ONLY_ACTIVE_ARCH", "YES")]
    proj_release = base + [("SWIFT_OPTIMIZATION_LEVEL", "-O"), ("VALIDATE_PRODUCT", "YES")]
    xcconfig(fid("xcconfig:proj:debug"), "Debug", proj_debug)
    xcconfig(fid("xcconfig:proj:release"), "Release", proj_release)
    tgt_common = [
        ("CODE_SIGN_STYLE", "Automatic"),
        ("COMBINE_HIDPI_IMAGES", "YES"),
        ("CURRENT_PROJECT_VERSION", "1"),
        ("DEVELOPMENT_TEAM", '""'),
        ("ENABLE_PREVIEWS", "YES"),
        ("GENERATE_INFOPLIST_FILE", "NO"),
        ("INFOPLIST_FILE", "Blob/Info.plist"),
        ("INFOPLIST_KEY_CFBundleDisplayName", "Blob"),
        ("LD_RUNPATH_SEARCH_PATHS", '"$(inherited) @executable_path/../Frameworks"'),
        ("MARKETING_VERSION", "0.1.0"),
        ("PRODUCT_BUNDLE_IDENTIFIER", "ai.blob.app"),
        ("PRODUCT_NAME", "$(TARGET_NAME)"),
        ("SWIFT_EMIT_LOC_STRINGS", "YES"),
    ]
    xcconfig(fid("xcconfig:target:debug"), "Debug", tgt_common + [("SWIFT_OPTIMIZATION_LEVEL", "-Onone")])
    xcconfig(fid("xcconfig:target:release"), "Release", tgt_common + [("SWIFT_OPTIMIZATION_LEVEL", "-O")])
    lines.append("/* End XCBuildConfiguration section */")
    lines.append("")
    lines.append("/* Begin XCConfigurationList section */")
    lines.append(f"\t\t{fid('xcconfiglist:project')} /* Build configuration list for PBXProject \"Blob\" */ = {{isa = XCConfigurationList; buildConfigurations = ({fid('xcconfig:proj:debug')} /* Debug */, {fid('xcconfig:proj:release')} /* Release */); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; }};")
    lines.append(f"\t\t{fid('xcconfiglist:target')} /* Build configuration list for PBXNativeTarget \"Blob\" */ = {{isa = XCConfigurationList; buildConfigurations = ({fid('xcconfig:target:debug')} /* Debug */, {fid('xcconfig:target:release')} /* Release */); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; }};")
    lines.append("/* End XCConfigurationList section */")
    lines.append("")
    lines.append("\t};")
    lines.append("\trootObject = %s /* Project object */;" % fid("project"))
    lines.append("}")

    # Products group + app file ref (needed by target)
    out = "\n".join(lines)
    products_insert = f"""\t\t{fid('grp:Products')} /* Products */ = {{isa = PBXGroup; children = ({fid('ref:Blob.app')} /* Blob.app */); name = Products; sourceTree = "<group>"; }};
\t\t{fid('ref:Blob.app')} /* Blob.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Blob.app; sourceTree = BUILT_PRODUCTS_DIR; }};"""
    out = out.replace("/* End PBXFileReference section */", products_insert + "\n/* End PBXFileReference section */")

    with open(os.path.join(proj_dir, "project.pbxproj"), "w") as f:
        f.write(out + "\n")
    print("project.pbxproj written")

if __name__ == "__main__":
    main()
