/**
 * Copyright: Copyright (c) 2016 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.main;

version (unittest) { }
else:

/**
 *  Application entry point, handles CLI/config and forwards to
 *  dstep.driver.Application to do actual work.
 */
int main (string[] args)
{
    import dstep.driver.CommandLine: run;
    return run(args);
}
