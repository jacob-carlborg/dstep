project('dstep', 'd', version: '1.0.1')

resource_dir = meson.current_source_dir() / 'resources'
add_project_arguments('-J=' + resource_dir, language: 'd')

src = [
    'clang/Compiler.d',
    'clang/Cursor.d',
    'clang/Diagnostic.d',
    'clang/File.d',
    'clang/Index.d',
    'clang/SourceLocation.d',
    'clang/SourceRange.d',
    'clang/Token.d',
    'clang/TranslationUnit.d',
    'clang/Type.d',
    'clang/Util.d',
    'clang/Visitor.d',
    'clang/c/BuildSystem.d',
    'clang/c/CXCompilationDatabase.d',
    'clang/c/CXErrorCode.d',
    'clang/c/CXString.d',
    'clang/c/Documentation.d',
    'clang/c/Index.d',
    'clang/c/Platform.d',
    'dstep/Configuration.d',
    'dstep/core/Exceptions.d',
    'dstep/driver/Application.d',
    'dstep/driver/CommandLine.d',
    'dstep/driver/Util.d',
    'dstep/translator/CommentIndex.d',
    'dstep/translator/Context.d',
    'dstep/translator/ConvertCase.d',
    'dstep/translator/Declaration.d',
    'dstep/translator/Enum.d',
    'dstep/translator/HeaderIndex.d',
    'dstep/translator/IncludeHandler.d',
    'dstep/translator/MacroDefinition.d',
    'dstep/translator/MacroIndex.d',
    'dstep/translator/MacroParser.d',
    'dstep/translator/Options.d',
    'dstep/translator/Output.d',
    'dstep/translator/Preprocessor.d',
    'dstep/translator/Record.d',
    'dstep/translator/Translator.d',
    'dstep/translator/Type.d',
    'dstep/translator/TypeInference.d',
    'dstep/translator/TypedefIndex.d',
    'dstep/translator/objc/Category.d',
    'dstep/translator/objc/ObjcInterface.d',
]

# Required for adding llvm as dependency
add_languages('cpp')
# Only clang is required, but adding llvm also add the directory where
# libclang.so is found
llvm = dependency('llvm')
# Link to clang
add_project_link_arguments('-L=-lclang', language: 'd')

executable(
    'dstep',
    src + [ 'dstep/main.d' ],
    dependencies: [ llvm ]
)

unittest_exe = executable(
    'dstep_unittest',
    src + [ 'dummy_main.d' ],
    dependencies: [ llvm ],
    d_unittest: true
)
test('unittest', unittest_exe)

