package sheenbidi

import "core:c"

// Architecture-specific library linking.
// The library/binding for SheenBidi is different depending on OS.
when ODIN_OS == .Linux {
    foreign import sheenbidi "libs/libsheenbidi.a"
}
when ODIN_OS == .Windows {
    // Disable linking with libc to avoid duplicate references (for some libraries).
    // This helps address certain linker warnings with Harfbuzz, for example.
    @(extra_linker_flags = "/NODEFAULTLIB:libcmt")
    foreign import sheenbidi "libs/sheenbidi.lib"
}

// Basic type aliases for SheenBidi.
SBUInteger :: c.uintptr_t     /// Typically used for indices and lengths.
SBUInt8    :: c.uint8_t
SBUInt32   :: c.uint32_t

SBCodepoint :: SBUInt32       /// A Unicode code point.

// String encoding enum for SheenBidi.
SBStringEncoding :: enum SBUInt32 {
    UTF8  = 0, /// 8-bit representation of Unicode code points.
    UTF16 = 1, /// 16-bit UTF encoding in native endianness.
    UTF32 = 2  /// 32-bit UTF encoding in native endianness.
}

// Boolean representation for SheenBidi.
SBBoolean :: enum SBUInt8 {
    False = 0, /// Represents a false/disabled state.
    True  = 1  /// Represents a true/enabled state.
}

// BiDi type classification for each code point.
SBBidiType :: enum SBUInt8 {
    Nil = 0x00,

    // Strong
    L  = 0x01, /// Left-to-Right
    R  = 0x02, /// Right-to-Left
    AL = 0x03, /// Right-to-Left Arabic

    // Weak
    BN  = 0x04, /// Boundary Neutral
    NSM = 0x05, /// Non-Spacing Mark
    AN  = 0x06, /// Arabic Number
    EN  = 0x07, /// European Number
    ET  = 0x08, /// European Number Terminator
    ES  = 0x09, /// European Number Separator
    CS  = 0x0A, /// Common Number Separator

    // Neutral
    WS  = 0x0B, /// White Space
    S   = 0x0C, /// Segment Separator
    B   = 0x0D, /// Paragraph Separator
    ON  = 0x0E, /// Other Neutral

    // Format
    LRI = 0x0F, /// Left-to-Right Isolate
    RLI = 0x10, /// Right-to-Left Isolate
    FSI = 0x11, /// First Strong Isolate
    PDI = 0x12, /// Pop Directional Isolate
    LRE = 0x13, /// Left-to-Right Embedding
    RLE = 0x14, /// Right-to-Left Embedding
    LRO = 0x15, /// Left-to-Right Override
    RLO = 0x16, /// Right-to-Left Override
    PDF = 0x17  /// Pop Directional Formatting
}

// BiDi level representation.
SBLevel :: enum SBUInt8 {
    Invalid     = 0xFF, /// Represents an invalid BiDi level.
    Max         = 125,  /// Maximum explicit embedding level.
    DefaultLTR  = 0xFE, /// Base level = 0 if no strong char found.
    DefaultRTL  = 0xFD  /// Base level = 1 if no strong char found.
}

// Basic codepoint sequence descriptor.
CodepointSequence :: struct {
    /// The string encoding (UTF-8, UTF-16, or UTF-32).
    stringEncoding: SBStringEncoding,

    /// Pointer to the source text buffer (the code units).
    stringBuffer: rawptr,

    /// The number of code units in the string.
    stringLength: SBUInteger,
}

// A run, describing a contiguous section in the BiDi context.
Run :: struct {
    /// Index to the first code unit in the source string for this run.
    offset: SBUInteger,

    /// Number of code units covering the run length.
    length: SBUInteger,

    /// The embedding level for this run.
    level: SBLevel,
}
// For safety or debugging, you might assert size_of(Run) == 24.

// A line object in SheenBidi (e.g., a piece of text from a paragraph).
SBLine :: struct {
    codepointSequence: CodepointSequence,
    fixedRuns:         ^Run,
    runCount:          SBUInteger,
    offset:            SBUInteger,
    length:            SBUInteger,
    retainCount:       SBUInteger,
}
SBLineRef :: ^SBLine
// Again, you might confirm size_of(SBLine) == 64 if needed.

// A top-level algorithm object from SheenBidi.
SBAlgorithm :: struct {
    codepointSequence: CodepointSequence,
    fixedTypes:        ^SBBidiType,
    retainCount:       SBUInteger,
}
SBAlgorithmRef :: ^SBAlgorithm
// Possibly check size_of(SBAlgorithm) == 40.

// A paragraph object within the SheenBidi algorithm.
SBParagraph :: struct {
    algorithm:   SBAlgorithmRef,
    refTypes:    ^SBBidiType,
    fixedLevels: ^SBLevel,
    offset:      SBUInteger,
    length:      SBUInteger,
    baseLevel:   SBLevel,
    retainCount: SBUInteger,
}
SBParagraphRef :: ^SBParagraph
// Possibly check size_of(SBParagraph) == 56.

// A representation of a mirrored character, used in the BiDi process.
SBMirrorAgent :: struct {
    /// Absolute index of the code point in the text.
    index:      SBUInteger,

    /// The mirrored code point form.
    mirror:     SBCodepoint,

    /// The actual code point from the source text.
    codepoint:  SBCodepoint,
}

// A locator used for enumerating mirrored code points in a line.
SBMirrorLocator :: struct {
    _line:       SBLineRef,
    _runIndex:   SBUInteger,
    _stringIndex:SBUInteger,
    agent:       SBMirrorAgent,
    retainCount: SBUInteger,
}
SBMirrorLocatorRef :: ^SBMirrorLocator
// Possibly check size_of(SBMirrorLocator) == 48.

// Link prefix sets Odin's symbol prefix for C calls to "SB"
@(link_prefix = "SB")

/// SheenBidi C function imports.
foreign sheenbidi {
    AlgorithmCreate :: proc(
        codepointSequence: ^CodepointSequence
    ) -> SBAlgorithmRef ---


    AlgorithmCreateParagraph :: proc(
        algorithm:       SBAlgorithmRef,
        paragraphOffset: SBUInteger,
        suggestedLength: SBUInteger,
        baseLevel:       SBLevel
    ) -> SBParagraphRef ---


    ParagraphGetLength :: proc(
        paragraph: SBParagraphRef
    ) -> SBUInteger ---


    ParagraphCreateLine :: proc(
        paragraph:  SBParagraphRef,
        lineOffset: SBUInteger,
        lineLength: SBUInteger
    ) -> SBLineRef ---


    LineGetRunCount :: proc(
        line: SBLineRef
    ) -> SBUInteger ---


    LineGetRunsPtr :: proc(
        line: SBLineRef
    ) -> [^]Run ---


    MirrorLocatorCreate :: proc() -> SBMirrorLocatorRef ---
    MirrorLocatorLoadLine :: proc(
        locator:      SBMirrorLocatorRef,
        line:         SBLineRef,
        stringBuffer: rawptr
    ) ---

    MirrorLocatorGetAgent :: proc(
        locator: SBMirrorLocatorRef
    ) -> ^SBMirrorAgent ---

    MirrorLocatorMoveNext :: proc(
        locator: SBMirrorLocatorRef
    ) -> SBBoolean ---

    MirrorLocatorRelease :: proc(
        locator: SBMirrorLocatorRef
    ) ---

    LineRelease :: proc(
        line: SBLineRef
    ) ---

    ParagraphRelease :: proc(
        paragraph: SBParagraphRef
    ) ---

    AlgorithmRelease :: proc(
        algorithm: SBAlgorithmRef
    ) ---
}
