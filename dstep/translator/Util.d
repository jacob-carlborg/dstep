module dstep.translator.Util;

/** In recent versions of clang (at least 19.1.7), unnamed (anonymous) types will not
 * set the spelling field to an empty string, but instead to a message like
 * "enum (unnamed at [declaration_file.h:48]"
 * "struct (anonymous at [declaration_file.h:48]"
 * Either unnamed or anonymous is used.
 * This applies to structs, enums and unions.
 *
 * structs and unions additionally have the isAnonymous() helper which doesn't for enums.
 *
 * Usage:
 *      cursor.spelling.isUnnamed()
 */
bool isUnnamed(string s){
    import std.algorithm.searching;
    return s == "" || 
            s.canFind("(unnamed at") ||
            s.canFind("(anonymous at");
}

