/**
 * Copyright: Copyright (c) 2016 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: May 26, 2016
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.translator.TypedefIndex;

import clang.c.Index;
import clang.Cursor;
import clang.TranslationUnit;

class TypedefIndex
{
    private Cursor[Cursor] typedefs;

    this(TranslationUnit translUnit)
    {
        bool[Cursor] visited;

        auto file = translUnit.file;

        foreach (cursor; translUnit.cursor.all)
        {
            if (cursor.file == file)
            {
                visited[cursor] = true;
                inspect(cursor, visited);
            }
        }
    }

    private void inspect(Cursor cursor, bool[Cursor] visited)
    {
        if (cursor.kind == CXCursorKind.CXCursor_TypedefDecl)
        {
            foreach (child; cursor.all)
            {
                if (child.kind == CXCursorKind.CXCursor_TypeRef
                    || child.isDeclaration)
                {
                    typedefs[child.referenced] = cursor;
                    typedefs[child.referenced.canonical] = cursor;
                }
            }
        }
        else if ((cursor in visited) is null)
        {
            foreach (child; cursor.all)
            {
                visited[cursor] = true;
                inspect(cursor, visited);
            }
        }
    }

    Cursor typedefParent(in Cursor cursor)
    {
        auto result = cursor in typedefs;

        if (result is null)
            return cursor.empty;
        else
            return *result;
    }
}
