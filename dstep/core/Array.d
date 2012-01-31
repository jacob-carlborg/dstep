/**
 * Copyright: Copyright (c) 2008-2012 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: 2008
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 * 
 */
module dstep.core.Array;

version (Tango)
{
	static import tango.core.Array;
	import tango.stdc.string : memmove;
	static import tango.text.Util;
}

else
{
	version = Phobos;
	
	import std.c.string : memmove;
	import algorithm = std.algorithm;
	import stdString = std.string;
}

import dstep.util.Traits;

version (Tango)
{
	alias tango.core.Array.map map;
	alias tango.core.Array.filter filter;
	alias tango.core.Array.reduce reduce;
}

/**
 * Inserts the specified element at the specified position in the array. Shifts the
 * element currently at that position (if any) and any subsequent elements to the right.
 * 
 * Params:
 *     arr = the array to insert the element into
 *     index = the index at which the specified element is to be inserted
 *     element = the element to be inserted
 *     
 * Returns: the modified array
 *     
 * Throws: AssertException if the length of the array is 0
 * Throws: AssertException if the $(D_PARAM index) argument is
 *         greater than the length of this array.
 */
T[] insert (T, U = size_t) (ref T[] arr, U index, T element)
in
{
	assert(arr.length > 0, "mambo.collection.Array.insert: The length of the array was 0");
	assert(index <= arr.length, "mambo.collection.Array.insert: The index was greater than the length of the array");
}
body
{
	if (index == arr.length)
	{
		arr ~= element;
		return arr;
	}

	else if (index == 0)
		arr = element ~ arr;

	else
		arr = arr[0 .. index] ~ element ~ arr[index .. $];

	return arr;
}

/**
 * Inserts the specified elements at the specified position in the array. Shifts the
 * element currently at that position (if any) and any subsequent elements to the right.
 * 
 * Params:
 *     arr = the array to insert the element into
 *     index = the index at which the specified element is to be inserted
 *     element = the element to be inserted
 *     
 * Returns: the modified array
 *     
 * Throws: AssertException if the length of the array is 0
 * Throws: AssertException if the $(D_PARAM index) argument is
 *         not less or equal than the length of this array. 
 */
T[] insert (T, U = size_t) (ref T[] arr, U index, T[] element)
in
{
	assert(arr.length > 0, "mambo.collection.Array.insert: The length of the array was 0");
	assert(index <= arr.length, "mambo.collection.Array.insert: The index was greater than the length of the array");
}
body
{
	if (index == arr.length)
	{
		arr ~= element;
		return arr;
	}

	else if (index == 0)
		arr = element ~ arr;

	else
		arr = arr[0 .. index] ~ element ~ arr[index .. $];

	return arr;
}

/**
 * Inserts the specified element at the specified position in the array. Shifts the
 * element currently at that position (if any) and any subsequent elements to the right.
 * 
 * Params:
 *     arr = the array to add the element to
 *     index = the index at which the specified element is to be inserted
 *     element = the element to be inserted
 *     
 * Returns: the modified array    
 *     
 * Throws: AssertException if the length of the array is 0
 * Throws: AssertException if the $(D_PARAM index) argument is
 *         not less than the length of this array.
 */
T[] add (T, U = size_t) (ref T[] arr, U index, T element)
in
{
	assert(arr.length > 0, "mambo.collection.Array.add: The length of the array was 0");
	assert(index <= arr.length, "mambo.collection.Array.add: The index was greater than the length of the array");
}
body
{
	return insert(arr, index, element);
}

/**
 * Appends the specified element to the end of the array.
 * 
 * Params:
 *     arr = the array to add the element to
 *     element = element to be appended to this list
 *     
 * Returns: the modified array
 */
T[] add (T) (ref T[] arr, T element)
{
	return arr ~= element;
}

/**
 * Removes the element at the specified position in the array if it could find it and
 * returns it. Shifts any subsequent elements to the left.
 * 
 * Params:
 *     arr = the array to remove the element from
 *     index = the index of the element to be removed
 *     
 * Returns: the element that was removed
 * 
 * Throws: AssertException if the length of the array is 0
 * Throws: AssertException if the $(D_PARAM index) argument is
 *         not less than the length of this array.
 */
T remove (T, U = size_t) (ref T[] arr, U index)
in
{
	assert(arr.length > 0, "mambo.collection.Array.remove: The length of the array was 0");
	assert(index < arr.length, "mambo.collection.Array.remove: The index was greater than the length of the array");
}
body
{
	T ret = arr[index];
	
	if (index == 0)
		arr = arr[1 .. $];
	
	else if (index == arr.length - 1)
		arr = arr[0 .. $ - 1];
	
	else
	{
		if (index < arr.length - 1)
			memmove(&arr[index], &arr[index + 1], T.sizeof * (arr.length - index - 1));

	    arr.length = arr.length - 1;
	}
	
	return ret;
}

/**
 * Removes the specified element from the array if it could find it and returns it.
 * Shifts any subsequent elements to the left.
 * 
 * Params:
 *     arr = the array to remove the element from
 *     element = the element to be removed
 *     
 * Returns: the element that was removed or T.max
 * 
 * Throws: AssertException if the length of the array is 0
 */
T remove (T) (ref T[] arr, T element)
in
{
	assert(arr.length > 0, "mambo.collection.Array.remove: The length of the array was 0");
}
out (result)
{
	assert(result is element);
}
body
{
	size_t index = arr.indexOf(element);

	if (index == size_t.max)
		return T.max;

	return arr.remove(index);
}

/**
 * Returns the index of the first occurrence of the specified element in the array, or
 * U.max if the array does not contain the element. 
 * 
 * Params:
 *     arr = the array to get the index of the element from
 *     element = the element to find
 *     start = the index where to begin the search
 *     
 * Returns: the index of the element or U.max if it's not in the array
 * 
 * Throws: AssertException if the length of the array is 0
 * Throws: AssertException if the return value is greater or   
 * 		   equal to the length of the array.
 */
U indexOf (T, U = size_t) (T[] arr, T element, U start = 0)
in
{
	assert(start >= 0, "mambo.collection.Array.indexOf: The start index was less than 0");
}
body
{
	version (Tango)
	{
		U index = tango.text.Util.locate(arr, element, start);
		
		if (index == arr.length)
			index = U.max;

		return index;
	}

	else
	{
		static if (isString!(T))
			return stdString.indexOf(arr, element);
		
		else
			return algorithm.find(arr[start .. $], element);
		
		/*if (start > arr.length)
			start = arr.length;
		
		for (U i = start; i < arr.length; i++)
			if (arr[i] == element)
				return i;
		
		return U.max;*/
	}
}

/**
 * Returns $(D_KEYWORD true) if the array contains the specified element.
 * 
 * Params:
 *     arr = the array to check if it contains the element
 *     element = the element whose presence in the array is to be tested
 *     
 * Returns: $(D_KEYWORD true) if the array contains the specified element
 * 
 * Throws: AssertException if the length of the array is 0
 */
bool contains (T) (T[] arr, T element)
in
{
	assert(arr.length > 0, "mambo.collection.Array.contains: The length of the array was 0");
}
body
{
	return arr.indexOf!(T, size_t)(element) < size_t.max;
}

/**
 * Returns $(D_KEYWORD true) if the array contains the given pattern.
 * 
 * Params:
 *     arr = the array to check if it contains the element
 *     pattern = the pattern whose presence in the array is to be tested
 *     
 * Returns: $(D_KEYWORD true) if the array contains the given pattern
 */
bool contains (T) (T[] arr, T[] pattern)
{
	static if (isChar!(T))
	{
		version (Tango)
			return tango.text.Util.containsPattern(arr, pattern);
		
		else
			return stdString.indexOf(arr, element) != -1;
	}
	
	else
	{
		version (Tango)
			return tango.core.Array.contains(arr, pattern);
		
		else
			return !algorithm.find(arr, pattern).empty;
	}
}

/**
 * Returns $(D_KEYWORD true) if this array contains no elements.
 * 
 * Params:
 *     arr = the array to check if it's empty
 *
 * Returns: $(D_KEYWORD true) if this array contains no elements
 */
bool isEmpty (T) (T[] arr)
{
	return arr.length == 0;
}

/**
 * Returns $(D_KEYWORD true) if this array contains no elements.
 * 
 * Params:
 *     arr = the array to check if it's empty
 *
 * Returns: $(D_KEYWORD true) if this array contains no elements
 */
alias isEmpty empty;

/**
 * Removes all of the elements from this array. The array will be empty after this call
 * returns.
 * 
 * Params:
 *     arr = the array to clear
 * 
 * Returns: the cleared array
 *
 * Throws: AssertException if length of the return array isn't 0
 */
T[] clear (T) (ref T[] arr)
out (result)
{
	assert(result.length == 0, "mambo.collection.Array.clear: The length of the resulting array was not 0");
}
body
{
	arr.length = 0;
	return arr;
}

/**
 * Returns the element at the specified position in the array.
 * 
 * Params:
 * 	   arr = the array to get the element from
 *     index = index of the element to return
 *     
 * Returns: the element at the specified position in the array
 * 
 * Throws: AssertException if the length of the array is 0
 * Throws: AssertException if the $(D_PARAM index) argument is
 *         not less than the length of this array.
 */
T get (T, U = size_t) (T[] arr, U index)
in
{
	assert(arr.length > 0, "mambo.collection.Array.get: The length of the array was 0");
	assert(index < arr.length, "mambo.collection.Array.get: The index was greater than the length of the array");
}
body
{
	return arr[index];
}

/**
 * Returns the index of the last occurrence of the specifed element
 * 
 * Params:
 *     arr = the array to get the index of the element from
 *     element = the element to find the index of
 *     
 * Returns: the index of the last occurrence of the element in the
 *          specified array, or U.max 
 *          if the element does not occur.
 *          
 * Throws: AssertException if the length of the array is 0 
 * Throws: AssertException if the return value is less than -1 or
 * 		   greater than the length of the array - 1.
 */
version (Tango)
{
	U lastIndexOf (T, U = size_t) (in T[] arr, T element)
	in
	{
		assert(arr.length > 0, "mambo.collection.Array.lastIndexOf: The length of the array was 0");
	}
	body
	{
		U index = tango.text.Util.locatePrior(arr, element);

		if (index == arr.length)
			return U.max;

		return index;
	}
}

else
{
	U lastIndexOf (T, U = size_t) (in T[] arr, dchar element)
	in
	{
		assert(arr.length > 0, "mambo.collection.Array.lastIndexOf: The length of the array was 0");
	}
	body
	{
		foreach_reverse (i, dchar e ; arr)
			if (e is element)
				return i;

		return U.max;
	}
}

/**
 * Returns the number of elements in the specified array. 
 * 
 * Params:
 *     arr = the array to get the number of elements from
 *     
 * Returns: the number of elements in this list
 */
U size (T, U = size_t) (T[] arr)
{
	return arr.length;
}

/**
 * Finds the first occurence of element in arr
 * 
 * Params:
 *     arr = the array to find the element in
 *     element = the element to find
 *     start = at which position to start finding
 *     
 * Returns: the index of the first match or U.max if no match was found.
 */
alias indexOf find;

/**
 * Replaces a section of $(D_PARAM arr) with elements starting at $(D_PARAM pos) ending
 * $(D_PARAM n) elements after
 * 
 * Params:
 *     arr = the array to do the replace in
 *     pos = position within the array of the first element of the section to be replaced
 *     n = length of the section to be replaced within the array
 *     elements = the elements to replace with
 *     
 * Throws:
 * 		AssertException if pos is greater than the length of the array
 * 
 * Returns: the array
 */
T[] replace (T, U = size_t) (ref T[] arr, U pos, U n, T[] elements)
in
{
	assert(pos <= arr.length, "mambo.collection.Array.replace: The position was greter than the length of the array");
}
body
{
	U i;
	U nr = n;
	
	if (nr > arr.length)
		nr = arr.length - 1;
	
	if (nr == elements.length)
	{
		U eIndex;

		for (i = pos, eIndex = 0; i <= nr; i++, eIndex++)
			arr[i] = elements[eIndex];			
		
		return arr;
	}
	
	else if (elements.length == 0)
	{
		U index = pos + n;
		
		if (index >= arr.length)
			index = arr.length;
		
		return arr = arr[0 .. pos] ~ arr[index .. $];
	}
	
	else
	{
		U eIndex;
		
		for (i = pos, eIndex = 0; eIndex < nr && i < arr.length && eIndex < elements.length; i++, eIndex++)
			arr[i] = elements[eIndex];
		
		// no positions left and elements are left in elements, insert elements
		if (eIndex < elements.length)
			return arr = arr[0 .. i] ~ elements[eIndex .. $] ~ arr[i .. $];
		
		// positions left to replace but no elements, remove those positions
		else if (nr > eIndex)
		{
			U index = pos + nr;
			
			if (index >= arr.length)
				index = arr.length;			
			
			return arr = arr[0 .. pos + eIndex] ~ arr[index .. $];
		}
			
	}
	
	return arr;
}

/**
 * Erases a part of the array content, shortening the length of the array.
 * 
 * Params:
 *     arr = the array to erase elements from
 *     start = the position within the array of the first element to be erased
 *     n = amount of elements to be removed. It may remove less elements if the
 *     	   end of the array is reached before the n elements have been erased.
 *     	   The default value of n indicates that all the elements until the end
 *     	   of the array should be erased.
 *     
 * Throws:
 * 		AssertException if pos is greater than the length of the array
 *     
 * Returns: the array
 */
T[] erase (T, U = size_t) (ref T[] arr, U start = 0, U n = U.max)
in
{
	assert(start <= arr.length, "mambo.collection.Array.erase: The start position was greater than the length of the array");
}
body
{	
	U end;
	
	if (n == U.max)
		end = arr.length;
	
	else
	{
		end = start + n;
		
		if (end > arr.length)
			end = arr.length;
	}
	
	return arr = arr[0 .. start] ~ arr[end .. $]; 
}

/**
 * Compares to arrays. Returns 0 if the content matches, less than zero 
 * if a is "less" than b, or greater than zero where a is "bigger".
 * 
 * Params:
 *     a = the first array 
 *     b = the second array
 *     end = the index where the comparision will end
 *     
 * Returns: Returns 0 if the content matches, less than zero if a is 
 * 			"less" than b, or greater than zero where a is "bigger".
 */
int compare (T, U = size_t) (T[] a, T[] b, U end = U.max)
{
	U ia = end;
	U ib = end;	
	
	if (ia > a.length)
		ia = a.length;
	
	if (ib > b.length)
		ib = b.length;
	
	return typeid(T[]).compare(&a[0 .. ia], &b[0 .. ib]);
}

/**
 * Compares the content of the given array to the content of a comparing 
 * array, which is formed according to the arguments passed.
 * 
 * The function returns 0 if all the elements in the compared contents compare
 * equal, a negative value if the first element that does not match compares to
 * less in the array than in the comparing array, and a positive value in
 * the opposite case.
 * 
 * Params:
 *     a = the first array to compare with
 *     pos = position of the beginning of the compared slice, i.e. the first element in the array (in a) to be compared against the comparing array.
 *     n = length of the compared slice.
 *     b = array with the content to be used as comparing array.
 *     
 * Returns: 0 if the compared array are equal, otherwise a number different from 0 is returned, with its sign indicating whether the array is considered greater than the comparing array passed as parameter (positive sign), or smaller (negative sign).
 * 
 * Throws: AssertException if pos is specified with a position greater than the length of the corresponding array
 */
int compare (T, U = size_t) (T[] a, size_t pos, size_t n, T[] b)
in
{
	assert(pos <= b.length);
}
body
{
	U end = pos + n;
	
	if (end > b.length)
		end = b.length;
	
	return typeid(T[]).compare(&b[pos .. end], &a[0 .. $]);
}

/**
 * Reserves the given amount of allocated storage for the given array.
 * 
 * Params:
 *     a = the array to reserve allocated storage for
 *     capacity = the amount of allocated storage to be reserved
 */
void reserve (T) (ref T[] a, size_t amount = 0)
{
	a = (new T[amount])[0 .. 0]; 
}

/**
 * Returns true if a begins with b
 * 
 * Params:
 *     a = the array to
 *     b = 
 *     
 * Returns: true if a begins with b, otherwise false
 */
bool beginsWith (T) (T[] a, T[] b)
{
	return a.length > b.length && a[0 .. b.length] == b;
}

/**
 * Returns true if a ends with b
 * 
 * Params:
 *     a = the array to
 *     b = 
 *     
 * Returns: true if a ends with b, otherwise false
 */
bool endsWith (T) (T[] a, T[] b)
{
	return a.length > b.length && a[$ - b.length .. $] == b;
}

/**
 * Repests $(D_PARAM arr) $(D_PARAM number) of times.
 * 
 * Params:
 *     arr = the array to repeat
 *     number = the number of times to repeat
 *     
 * Returns: a new array containing $(D_PARAM arr) $(D_PARAM number) of times
 */
T[] repeat (T) (T[] arr, int number)
{
	T[] result;
	
	for (int i = 0; i <= number; i++)
		result ~= arr;
	
	return result;
}

/**
 * Returns $(D_KEYWORD true) if this array contains any elements.
 * 
 * Params:
 *     arr = the array to check if it contains elements
 *
 * Returns: $(D_KEYWORD true) if this array contains elements
 */
bool any (T) (T[] arr)
{
	return arr.length > 0;
}

/// Returns the first element of the array
T first (T) (T[] arr)
{
	return arr[0];
}

/// Returns the last element of the array
T last (T) (T[] arr)
{
	return arr[$ - 1];
}