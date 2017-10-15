/**
 * Copyright: Copyright (c) 2017 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: September 23, 2017
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */

import Common;
import dstep.translator.Options;

// Fix 141: Use of _IO, _IOR, etc.
unittest
{
    assertTranslates(q"C
#define _IOC_NRSHIFT	0
#define _IOC_TYPESHIFT	1
#define _IOC_SIZESHIFT	2
#define _IOC_DIRSHIFT	3

#define _IOC_NONE	0U
#define _IOC_READ	2U

#define _IOC(dir,type,nr,size) \
	(((dir)  << _IOC_DIRSHIFT) | \
	 ((type) << _IOC_TYPESHIFT) | \
	 ((nr)   << _IOC_NRSHIFT) | \
	 ((size) << _IOC_SIZESHIFT))

#define _IOC_TYPECHECK(t) (sizeof(t))

#define _IO(type,nr)		_IOC(_IOC_NONE,(type),(nr),0)
#define _IOR(type,nr,size)	_IOC(_IOC_READ,(type),(nr),(_IOC_TYPECHECK(size)))

typedef struct { } foo_status_t;
typedef unsigned int __u32;
typedef unsigned short __u16;

#define FE_READ_STATUS _IOR('o', 69, foo_status_t)
#define FE_READ_BER _IOR('o', 70, __u32)
#define FE_READ_SIGNAL_STRENGTH _IOR('o', 71, __u16)
#define FE_READ_SNR _IOR('o', 72, __u16)
#define FE_READ_UNCORRECTED_BLOCKS _IOR('o', 73, __u32)
C",
q"D
extern (C):

enum _IOC_NRSHIFT = 0;
enum _IOC_TYPESHIFT = 1;
enum _IOC_SIZESHIFT = 2;
enum _IOC_DIRSHIFT = 3;

enum _IOC_NONE = 0U;
enum _IOC_READ = 2U;

extern (D) auto _IOC(T0, T1, T2, T3)(auto ref T0 dir, auto ref T1 type, auto ref T2 nr, auto ref T3 size)
{
    return (dir << _IOC_DIRSHIFT) | (type << _IOC_TYPESHIFT) | (nr << _IOC_NRSHIFT) | (size << _IOC_SIZESHIFT);
}

extern (D) size_t _IOC_TYPECHECK(t)()
{
    return t.sizeof;
}

extern (D) auto _IO(T0, T1)(auto ref T0 type, auto ref T1 nr)
{
    return _IOC(_IOC_NONE, type, nr, 0);
}

extern (D) auto _IOR(size, T0, T1)(auto ref T0 type, auto ref T1 nr)
{
    return _IOC(_IOC_READ, type, nr, _IOC_TYPECHECK!size());
}

struct foo_status_t
{
}

enum FE_READ_STATUS = _IOR!foo_status_t('o', 69);
enum FE_READ_BER = _IOR!uint('o', 70);
enum FE_READ_SIGNAL_STRENGTH = _IOR!ushort('o', 71);
enum FE_READ_SNR = _IOR!ushort('o', 72);
enum FE_READ_UNCORRECTED_BLOCKS = _IOR!uint('o', 73);
D");

}
