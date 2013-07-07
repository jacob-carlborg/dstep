/**
 * Copyright: Copyright (c) 2011 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Oct 1, 2011
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.driver.DStep;

import dstep.driver.Application;
import dstep.config.Configuration;

int main (string[] args)
{
	Application.instance.config = new Configuration;
	return Application.start!Application(args);
}
