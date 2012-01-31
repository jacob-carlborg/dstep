/**
 * Copyright: Copyright (c) 2008-2012 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: 2008
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 * 
 */
module dstep.core.string;

public import dstep.core.Array;
import dstep.util.Traits;

version (Tango)
{
	static import tango.stdc.stringz;
	import tango.text.Unicode : toFold, isDigit;
	import tango.text.convert.Utf;
	import tango.text.Util;
	import tango.text.convert.Format : format = Format;
	
	alias tango.stdc.stringz.toStringz toStringz;
	alias tango.stdc.stringz.toString16z toString16z;
	alias tango.stdc.stringz.toString32z toString32z;
	
	alias tango.stdc.stringz.fromStringz fromStringz;
	alias tango.stdc.stringz.fromString16z fromString16z;
	alias tango.stdc.stringz.fromString32z fromString32z;
	
	alias tango.text.convert.Utf.toString16 toString16;
	alias tango.text.convert.Utf.toString32 toString32;
}

else
{	
	import std.string;
	import std.utf;
	import std.ctype : isxdigit;
	import std.conv;
	
	version = Phobos;
	
	private alias std.string.tolower toFold;
	
	alias std.utf.toUTF8 toString;
	alias std.utf.toUTF16 toString16;
	alias std.utf.toUTF32 toString32;
	
	alias std.string.toStringz toStringz;
	alias std.utf.toUTF16z toString16z;
	
	alias to!(string) fromStringz;
	
	alias std.string.format format;
}

/**
 * Compares the $(D_PSYMBOL string) to another $(D_PSYMBOL string), ignoring case
 * considerations.  Two strings are considered equal ignoring case if they are of the
 * same length and corresponding characters in the two strings  are equal ignoring case.
 * 
 * Params:
 *     str = The $(D_PSYMBOL string) first string to compare to
 *     anotherString = The $(D_PSYMBOL string) to compare the first $(D_PSYMBOL string) with
 *     
 * Returns: $(D_KEYWORD true) if the arguments is not $(D_KEYWORD null) and it
 *          represents an equivalent $(D_PSYMBOL string) ignoring case; $(D_KEYWORD false) otherwise
 *          
 * Throws: AssertException if the length of any of the strings is 0
 *          
 * See_Also: opEquals(Object)
 */
bool equalsIgnoreCase (string str, string anotherString)
in
{
	assert(str.length > 0, "mambo.string.equalsIgnoreCase: The length of the first string was 0");
	assert(anotherString.length > 0, "mambo.string.equalsIgnoreCase: The length of the second string was 0");
}
body
{	
	if (str == anotherString)
		return true;

	return toFold(str) == toFold(anotherString);
}

/**
 * Compares the $(D_PSYMBOL wstring) to another $(D_PSYMBOL wstring), ignoring case
 * considerations. Two wstrings are considered equal ignoring case if they are of the
 * same length and corresponding characters in the two wstrings are equal ignoring case.
 * 
 * Params:
 *     str = The $(D_PSYMBOL wstring) first string to compre to
 *     anotherString = The $(D_PSYMBOL wstring) to compare the first $(D_PSYMBOL wstring) against
 *     
 * Returns: $(D_KEYWORD true) if the argument is not $(D_KEYWORD null) and it
 *          represents an equivalent $(D_PSYMBOL wstring) ignoring case; (D_KEYWORD
 *          false) otherwise
 *          
 * Throws: AssertException if the length of any of the wstrings is 0
 *          
 * See_Also: opEquals(Object)
 */
bool equalsIgnoreCase (wstring str, wstring anotherString)
in
{
	assert(str.length > 0, "mambo.string.equalsIgnoreCase: The length of the first string was 0");
	assert(anotherString.length > 0, "mambo.string.equalsIgnoreCase: The length of the second string was 0");
}
body
{
	if (str == anotherString)
		return true;

	version (Tango)
		return toFold(str) == toFold(anotherString);

	else
		return toFold(toUTF8(str)) == toFold(toUTF8(anotherString));
}

/**
 * Compares the $(D_PSYMBOL dstring) to another $(D_PSYMBOL dstring), ignoring case
 * considerations. Two wstrings are considered equal ignoring case if they are of the
 * same length and corresponding characters in the two wstrings are equal ignoring case.
 * 
 * Params:
 *     str = The $(D_PSYMBOL dstring) first string to compare to
 *     anotherString = The $(D_PSYMBOL wstring) to compare the first $(D_PSYMBOL dstring) against
 *     
 * Returns: $(D_KEYWORD true) if the argument is not $(D_KEYWORD null) and it
 *          represents an equivalent $(D_PSYMBOL dstring) ignoring case; $(D_KEYWORD false) otherwise
 *          
 * Throws: AssertException if the length of any of the dstrings are 0
 *          
 * See_Also: opEquals(Object)
 */
bool equalsIgnoreCase (dstring str, dstring anotherString)
in
{
	assert(str.length > 0, "mambo.string.equalsIgnoreCase: The length of the first string was 0");
	assert(anotherString.length > 0, "mambo.string.equalsIgnoreCase: The length of the second string was 0");
}
body
{
	if (str == anotherString)
		return true;

	version (Tango)
		return toFold(str) == toFold(anotherString);

	else
		return toFold(toUTF8(str)) == toFold(toUTF8(anotherString));
}

/**
 * Returns the char value at the specified index. An index ranges from 0 to length - 1.
 * The first $(D_KEYWORD char) value of the sequence is at index 0, the next at index 1,
 * and so on, as for array indexing.
 * 
 * Params:
 * 	   str = the string to get the $(D_KEYWORD char) from
 *     index = the index of the $(D_KEYWORD char) value.
 *     
 * Returns: the $(D_KEYWORD char) value at the specified index of the string.
 *          The first $(D_KEYWORD char) value is at index 0.
 * 
 * Throws: AssertException if the length of the string is 0
 * Throws: AssertException if the $(D_CODE index) argument is
 *         not less than the length of the string.
 */
char charAt (string str, size_t index)
in
{
	assert(str.length > 0, "mambo.string.charAt: The length of the string was 0");
	assert(index <= str.length, "mambo.string.charAt: The index was to greater than the length of the string");
}
body
{
	return str[index];
}

/**
 * Returns the $(D_KEYWORD char) value at the specified index. An index ranges from 0 to
 * length - 1. The first $(D_KEYWORD char) value of the sequence is at index 0, the next
 * at index 1, and so on, as for array indexing.
 * 
 * Params:
 * 	   str = the wstring to get the $(D_KEYWORD char) from
 *     index = the index of the $(D_KEYWORD char) value.
 *     
 * Returns: the $(D_KEYWORD char) value at the specified index of the wstring.
 *          The first $(D_KEYWORD char) value is at index 0.
 * 
 * Throws: AssertException if the length of the wstring is 0
 * Throws: AssertException if the $(D_CODE index) argument is
 *         not less than the length of the wstring.
 */
wchar charAt (wstring str, size_t index)
in
{
	assert(str.length > 0, "mambo.string.charAt: The length of the string was 0");
	assert(index <= str.length, "mambo.string.charAt: The index was to greater than the length of the string");
}
body
{
	return str[index];
}

/**
 * Returns the $(D_KEYWORD char) value at the specified index. An index ranges from 0 to
 * length - 1. The first $(D_KEYWORD char) value of the sequence is at index 0, the next
 * at index 1, and so on, as for array indexing.
 * 
 * Params:
 * 	   str = the dstring to get the $(D_KEYWORD char) from
 *     index = the index of the $(D_KEYWORD char) value.
 *     
 * Returns: the $(D_KEYWORD char) value at the specified index of the dstring.
 *          The first $(D_KEYWORD char) value is at index 0.
 * 
 * Throws: AssertException if the length of the dstring is 0
 * Throws: AssertException if the $(D_CODE index) argument is
 *         not less than the length of the dstring.
 */
dchar charAt (dstring str, size_t index)
in
{
	assert(str.length > 0, "mambo.string.charAt: The length of the string was 0");
	assert(index <= str.length, "mambo.string.charAt: The index was to greater than the length of the string");
}
body
{
	return str[index];
}

/**
 * Returns a new string that is a substring of the specified string. The substring begins
 * at the specified $(D_PARAM beginIndex) and extends to the character at index
 * $(D_PARAM endIndex) - 1. Thus the length of the substring is $(D_PARAM endIndex - beginIndex).
 * 
 * Examples:
 * ---
 * "hamburger".substring(4, 8) returns "urge"
 * "smiles".substring(1, 5) returns "mile"
 * ---
 * 
 * Params:
 * 	   str = the string to get the substring from
 *     beginIndex = the beginning index, inclusive.
 *     endIndex = the ending index, exclusive.
 *     
 * Returns: the specified substring.
 * 
 * Throws: AssertException if the length of the string is 0
 * Throws: AssertException if the $(D_PARAM beginIndex) is 
 * 		   larger than $(D_PARAM endIndex).
 * Throws: AssertException if $(D_PARAM endIndex) is larger than the 
 *  	   length of the $(D_PSYMBOL string).
 */
string substring (string str, size_t beginIndex, size_t endIndex)
in
{
	assert(str.length > 0, "mambo.string.substring: The length of the string was 0");
	assert(beginIndex < endIndex, "mambo.string.substring: The first index was greater the second");
	assert(endIndex <= str.length, "mambo.string.substring: The second index was greater then the length of the string");
}
body
{
	return str[beginIndex .. endIndex].idup;
}

/**
 * Returns a new string that is a substring of the specified string. The substring begins
 * at the specified $(D_PARAM beginIndex) and extends to the character at index
 * $(D_PARAM endIndex) - 1. Thus the length of the substring is $(D_PARAM endIndex - beginIndex).
 * 
 * Examples:
 * ---
 * "hamburger".substring(4, 8) returns "urge"
 * "smiles".substring(1, 5) returns "mile"
 * ---
 * 
 * Params:
 * 	   str = the string to get the substring from
 *     beginIndex = the beginning index, inclusive.
 *     endIndex = the ending index, exclusive.
 *     
 * Returns: the specified substring.
 * 
 * Throws: AssertException if the length of the string is 0
 * Throws: AssertException if the $(D_PARAM beginIndex) is 
 * 		   larger than $(D_PARAM endIndex).
 * Throws: AssertException if $(D_PARAM endIndex) is larger than the 
 *  	   length of the $(D_PSYMBOL string).
 */
wstring substring (wstring str, size_t beginIndex, size_t endIndex)
in
{
	assert(str.length > 0, "mambo.string.substring: The length of the string was 0");
	assert(beginIndex < endIndex, "mambo.string.substring: The first index was greater the second");
	assert(endIndex <= str.length, "mambo.string.substring: The second index was greater then the length of the string");
}
body
{
	return str[beginIndex .. endIndex].idup;
}

/**
 * Returns a new string that is a substring of the specified string. The substring begins
 * at the specified $(D_PARAM beginIndex) and extends to the character at index
 * $(D_PARAM endIndex) - 1. Thus the length of the substring is $(D_PARAM endIndex - beginIndex).
 * 
 * Examples:
 * ---
 * "hamburger".substring(4, 8) returns "urge"
 * "smiles".substring(1, 5) returns "mile"
 * ---
 * 
 * Params:
 * 	   str = the string to get the substring from
 *     beginIndex = the beginning index, inclusive.
 *     endIndex = the ending index, exclusive.
 *     
 * Returns: the specified substring.
 * 
 * Throws: AssertException if the length of the string is 0
 * Throws: AssertException if the $(D_PARAM beginIndex) is 
 * 		   larger than $(D_PARAM endIndex).
 * Throws: AssertException if $(D_PARAM endIndex) is larger than the 
 *  	   length of the $(D_PSYMBOL string).
 */
dstring substring (dstring str, size_t beginIndex, size_t endIndex)
in
{
	assert(str.length > 0, "mambo.string.substring: The length of the string was 0");
	assert(beginIndex < endIndex, "mambo.string.substring: The first index was greater the second");
	assert(endIndex <= str.length, "mambo.string.substring: The second index was greater then the length of the string");
}
body
{
	return str[beginIndex .. endIndex].idup;
}

/**
 * Returns a new string that is a substring of the specified string. The substring begins
 * with the character at the specified index and extends to the end of the string. 
 * 
 * Examples:
 * ---
 * "unhappy".substring(2) returns "happy"
 * "Harbison".substring(3) returns "bison"
 * "emptiness".substring(9) returns "" (an empty string)
 * ---
 * 
 * Params:
 *     str = the string to get the substring from
 *     beginIndex = the beginning index, inclusive
 *     
 * Returns: the specified substring
 * 
 * Throws: AssertException if the length of the string is 0
 * Throws: AssertException if the $(D_PARAM beginIndex) is 
 * 		   larger than the length of the string.
 */
string substring (string str, size_t index)
in
{
	assert(str.length > 0, "mambo.string.substring: The length of the string was 0");
	assert(index < str.length, "mambo.string.substring: The index was greater than the length of the string");
}
body
{
	return str.substring(index, str.length);
}

/**
 * Returns a new string that is a substring of the specified string. The substring begins
 * with the character at the specified index and extends to the end of the string. 
 * 
 * Examples:
 * ---
 * "unhappy".substring(2) returns "happy"
 * "Harbison".substring(3) returns "bison"
 * "emptiness".substring(9) returns "" (an empty string)
 * ---
 * 
 * Params:
 *     str = the string to get the substring from
 *     beginIndex = the beginning index, inclusive
 *     
 * Returns: the specified substring
 * 
 * Throws: AssertException if the length of the string is 0
 * Throws: AssertException if the $(D_PARAM beginIndex) is 
 * 		   larger than the length of the string.
 */
wstring substring (wstring str, size_t index)
in
{
	assert(str.length > 0, "mambo.string.substring: The length of the string was 0");
	assert(index < str.length, "mambo.string.substring: The index was greater than the length of the string");
}
body
{
	return str.substring(index, str.length);
}

/**
 * Returns a new string that is a substring of the specified string. The substring begins
 * with the character at the specified index and extends to the end of the string. 
 * 
 * Examples:
 * ---
 * "unhappy".substring(2) returns "happy"
 * "Harbison".substring(3) returns "bison"
 * "emptiness".substring(9) returns "" (an empty string)
 * ---
 * 
 * Params:
 *     str = the string to get the substring from
 *     beginIndex = the beginning index, inclusive
 *     
 * Returns: the specified substring
 * 
 * Throws: AssertException if the length of the string is 0
 * Throws: AssertException if the $(D_PARAM beginIndex) is 
 * 		   larger than the length of the string.
 */
dstring substring (dstring str, size_t index)
in
{
	assert(str.length > 0, "mambo.string.substring: The length of the string was 0");
	assert(index < str.length, "mambo.string.substring: The index was greater than the length of the string");
}
body
{
	return str.substring(index, str.length);
}

/**
 * Returns a new string that is a substring of the given string.
 * 
 * This substring is the character sequence that starts at character
 * position pos and has a length of n characters.
 * 
 * Params:
 *     str = the string to get the substring from
 *     pos = position of a character in the current string to be used 
 *     		 as starting character for the substring.
 *     n = Length of the substring. If this value would make the 
 *     	   substring to span past the end of the current string content,
 *     	   only those characters until the end of the string are used. 
 *     	   size_t.max is the greatest possible value for an element of
 *     	   type size_t, therefore, when this value is used, all the
 *     	   characters between pos and the end of the string are used as
 *     	   the initialization substring.
 *     
 * Returns: a string containing a substring of the given string
 * 
 * Throws: AssertException if pos is greater than the length of the string
 */
string substr (string str, size_t pos = 0, size_t n = size_t.max)
in
{
	assert(pos < str.length, "mambo.string.substr: The given position was greater than the length of the string.");
}
body
{
	size_t end;
	
	if (n == size_t.max)
		end = str.length;
	
	else
	{
		end = pos + n;
		
		if (end > str.length)
			end = str.length;
	}
	
	return str[pos .. end].idup;
}

/**
 * Returns a new string that is a substring of the given string.
 * 
 * This substring is the character sequence that starts at character
 * position pos and has a length of n characters.
 * 
 * Params:
 *     str = the string to get the substring from
 *     pos = position of a character in the current string to be used 
 *     		 as starting character for the substring.
 *     n = Length of the substring. If this value would make the 
 *     	   substring to span past the end of the current string content,
 *     	   only those characters until the end of the string are used. 
 *     	   size_t.max is the greatest possible value for an element of
 *     	   type size_t, therefore, when this value is used, all the
 *     	   characters between pos and the end of the string are used as
 *     	   the initialization substring.
 *     
 * Returns: a string containing a substring of the given string
 * 
 * Throws: AssertException if pos is greater than the length of the string
 */
wstring substr (wstring str, size_t pos = 0, size_t n = size_t.max)
in
{
	assert(pos < str.length, "mambo.string.substr: The given position was greater than the length of the string.");
}
body
{
	size_t end;
	
	if (n == size_t.max)
		end = str.length;
	
	else
	{
		end = pos + n;
		
		if (end > str.length)
			end = str.length;
	}
	
	return str[pos .. end].idup;
}

/**
 * Returns a new string that is a substring of the given string.
 * 
 * This substring is the character sequence that starts at character
 * position pos and has a length of n characters.
 * 
 * Params:
 *     str = the string to get the substring from
 *     pos = position of a character in the current string to be used 
 *     		 as starting character for the substring.
 *     n = Length of the substring. If this value would make the 
 *     	   substring to span past the end of the current string content,
 *     	   only those characters until the end of the string are used. 
 *     	   size_t.max is the greatest possible value for an element of
 *     	   type size_t, therefore, when this value is used, all the
 *     	   characters between pos and the end of the string are used as
 *     	   the initialization substring.
 *     
 * Returns: a string containing a substring of the given string
 * 
 * Throws: AssertException if pos is greater than the length of the string
 */
dstring substr (dstring str, size_t pos = 0, size_t n = size_t.max)
in
{
	assert(pos < str.length, "mambo.string.substr: The given position was greater than the length of the string.");
}
body
{
	size_t end;
	
	if (n == size_t.max)
		end = str.length;
	
	else
	{
		end = pos + n;
		
		if (end > str.length)
			end = str.length;
	}
	
	return str[pos .. end].idup;
}

/**
 * Finds the first occurence of sub in str
 * 
 * Params:
 *     str = the string to find in
 *     sub = the substring to find
 *     start = where to start finding
 *     
 * Returns: the index of the substring or size_t.max when nothing was found
 */
size_t find (string str, string sub, size_t start = 0)
{
	version (Tango)
	{
		size_t index = str.locatePattern(sub, start);
		
		if (index == str.length)
			return size_t.max;
		
		return index;
	}
	
	else
		return std.string.find(str, sub, start);
}

/**
 * Finds the first occurence of sub in str
 * 
 * Params:
 *     str = the string to find in
 *     sub = the substring to find
 *     start = where to start finding
 *     
 * Returns: the index of the substring or size_t.max when nothing was found
 */
size_t find (wstring str, wstring sub, size_t start = 0)
{
	version (Tango)
	{
		size_t index = str.locatePattern(sub, start);
		
		if (index == str.length)
			return size_t.max;
		
		return index;
	}
	
	else
		return std.string.find(str, sub, start);
}

/**
 * Finds the first occurence of sub in str
 * 
 * Params:
 *     str = the string to find in
 *     sub = the substring to find
 *     start = where to start finding
 *     
 * Returns: the index of the substring or size_t.max when nothing was found
 */
size_t find (dstring str, dstring sub, size_t start = 0)
{
	version (Tango)
	{
		size_t index = str.locatePattern(sub, start);
		
		if (index == str.length)
			return size_t.max;
		
		return index;
	}
	
	else
		return std.string.find(str, sub, start);
}

/**
 * Compares to strings, ignoring case differences. Returns 0 if the content
 * matches, less than zero if a is "less" than b, or greater than zero
 * where a is "bigger".
 * 
 * Params:
 *     a = the first array 
 *     b = the second array
 *     end = the index where the comparision will end
 *     
 * Returns: Returns 0 if the content matches, less than zero if a is 
 * 			"less" than b, or greater than zero where a is "bigger".
 * 
 * See_Also: mambo.collection.array.compare
 */
int compareIgnoreCase (U = size_t) (string a, string b, U end = U.max)
{
	return a.toFold().compare(b.toFold(), end);
}

/**
 * Compares to strings, ignoring case differences. Returns 0 if the content
 * matches, less than zero if a is "less" than b, or greater than zero
 * where a is "bigger".
 * 
 * Params:
 *     a = the first array 
 *     b = the second array
 *     end = the index where the comparision will end
 *     
 * Returns: Returns 0 if the content matches, less than zero if a is 
 * 			"less" than b, or greater than zero where a is "bigger".
 * 
 * See_Also: mambo.collection.array.compare
 */
int compareIgnoreCase (U = size_t) (wstring a, wstring b, U end = U.max)
{
	return a.toFold().compare(b.toFold(), end);
}

/**
 * Compares to strings, ignoring case differences. Returns 0 if the content
 * matches, less than zero if a is "less" than b, or greater than zero
 * where a is "bigger".
 * 
 * Params:
 *     a = the first array 
 *     b = the second array
 *     end = the index where the comparision will end
 *     
 * Returns: Returns 0 if the content matches, less than zero if a is 
 * 			"less" than b, or greater than zero where a is "bigger".
 * 
 * See_Also: mambo.collection.array.compare
 */
int compareIgnoreCase (U = size_t) (dstring a, dstring b, U end = U.max)
{
	return a.toFold().compare(b.toFold(), end);
}

/**
 * Compares to strings, ignoring case differences. Returns 0 if the content
 * matches, less than zero if a is "less" than b, or greater than zero
 * where a is "bigger".
 * 
 * Params:
 *     a = the first array 
 *     b = the second array
 *     end = the index where the comparision will end
 *     
 * Returns: Returns 0 if the content matches, less than zero if a is 
 * 			"less" than b, or greater than zero where a is "bigger".
 * 
 * See_Also: mambo.string.compareIgnoreCase
 */
alias compareIgnoreCase icompare;

/**
 * Checks if the given character is a hexdecimal digit character.
 * Hexadecimal digits are any of: 0 1 2 3 4 5 6 7 8 9 a b c d e f A B C D E F
 * 
 * Params:
 *     ch = the character to be checked
 *     
 * Returns: true if the given character is a hexdecimal digit character otherwise false
 */
bool isHexDigit (dchar ch)
{
	version (Tango)
	{
		switch (ch)
		{
			case 'A': return true;				
			case 'B': return true;
			case 'C': return true;
			case 'D': return true;
			case 'E': return true;
			case 'F': return true;
			
			case 'a': return true;
			case 'b': return true;
			case 'c': return true;
			case 'd': return true;
			case 'e': return true;
			case 'f': return true;
			
			default: break;
		}
		
		if (isDigit(ch))
			return true;
	}

	else
		if (isxdigit(ch) != 0)
			return true;
		
	return false;
}

/*version (Tango)
{
	string toString (string str)
	{
		return str;
	}
	
	string toString (wstring str)
	{
		return tango.text.convert.Utf.toString(str);
	}
	
	string toString (dstring str)
	{
		return tango.text.convert.Utf.toString(str);
	}
}*/

version (Phobos)
{	
	/**
	 * Converts the given string to C-style 0 terminated string.
	 * 
	 * Params:
	 *     str = the string to convert
	 *     
	 * Returns: the a C-style 0 terminated string.
	 */
	dchar* toString32z (dstring str)
	{
		return (str ~ '\0').ptr;
	}
	
	/**
	 * Converts a C-style 0 terminated string to a wstring
	 * 
	 * Params:
	 *     str = the C-style 0 terminated string
	 *     
	 * Returns: the converted wstring
	 */
	wstring fromString16z (wchar* str)
	{
		return str[0 .. strlen(str)];
	}
	
	/**
	 * Converts a C-style 0 terminated string to a dstring
	 * Params:
	 *     str = the C-style 0 terminated string
	 *     
	 * Returns: the converted dstring
	 */
	dstring fromString32z (dchar* str)
	{
		return str[0 .. strlen(str)];
	}
	
	/**
	 * Gets the length of the given C-style 0 terminated string
	 * 
	 * Params:
	 *     str = the C-style 0 terminated string to get the length of
	 *     
	 * Returns: the length of the string
	 */
	size_t strlen (wchar* str)
	{
		size_t i = 0;
		
		if (str)
			while(*str++)
				++i;
		
		return i;
	}
	
	/**
	 * Gets the length of the given C-style 0 terminated string
	 * 
	 * Params:
	 *     str = the C-style 0 terminated string to get the length of
	 *     
	 * Returns: the length of the string
	 */
	size_t strlen (dchar* str)
	{
		size_t i = 0;
		
		if (str)
			while(*str++)
				++i;
		
		return i;
	}
}

T[] replace (T) (T[] source, dchar match, dchar replacement)
{
	static assert(isChar!(T), `The type "` ~ T.stringof ~ `" is not a valid type for this function only strings are accepted`);
	
	dchar endOfCodeRange;
	
	static if (is(T == wchar))
	{
		const encodedLength = 2;
		endOfCodeRange = 0x00FFFF;
	}
	
	else static if (is(T == char))
	{
		const encodedLength = 4;
		endOfCodeRange = '\x7F';
	}
	
	if (replacement <= endOfCodeRange && match <= endOfCodeRange)
	{
		foreach (ref c ; source)
			if (c == match)
				c = replacement;
		
		return source;
	}
	
	else
	{
		static if (!is(T == dchar))
		{
			T[encodedLength] encodedMatch;
			T[encodedLength] encodedReplacement;
			
			version (Tango)
				return source.substitute(encode(encodedMatch, match), encode(encodedReplacement, replacement));
			
			else
			{
				auto matchLength = encode(encodedMatch, match);
				auto replacementLength = encode(encodedReplacement, replacement);
				
				return std.string.replace(source, encodedMatch[0 .. matchLength], encodedReplacement[0 .. replacementLength]);
			}
		}
	}
	
	return source;
}

/**
 * Returns true if the given string is blank. A string is considered blank if any of
 * the following conditions are true:
 * 
 * $(UL
 * 	$(LI The string is null)
 * 	$(LI The length of the string is equal to 0)
 * 	$(LI The string is equal to the empty string, "")
 * )
 * 
 * Params:
 *     str = the string to test if it's blank
 *     
 * Returns: $(D_KEYWORD true) if any of the above conditions are met
 * 
 * See_Also: isPresent 
 */
bool isBlank (T) (T[] str)
{
	return str is null || str.length == 0 || str == "";
}

/**
 * Returns true if the given string is present. A string is conditions present if all
 * of the following conditions are true:
 * 
 * $(UL
 * 	$(LI The string is not null)
 * 	$(LI The length of the string is greater than 0)
 * 	$(LI The string is not equal to the empty string, "")
 * )
 * 
 * The above conditions are basically the opposite of isBlank.
 * 
 * Params:
 *     str = the string to test if it's present
 *     
 * Returns: $(D_KEYWORD true) if all of the above conditions are met
 * 
 * See_Also: isBlank
 */
bool isPresent (T) (T[] str)
{
	return !str.isBlank();
}