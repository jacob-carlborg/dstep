/**
 * Copyright: Copyright (c) 2012 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Aug 26, 2012
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.config.Configuration;

import DStack = dstack.application.Configuration;

class Configuration : DStack.Configuration
{
	auto appName = "DStep";
	auto appVersion = "0.0.1";

	this ()
	{
		super(this);
	}
}