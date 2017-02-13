/**
 * Copyright: Copyright (c) 2016 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: Aug 26, 2016
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */

import Common;

// Fix 8: Typedef and anonymous structs.

unittest
{
    assertTranslates(q"C
#include <stdint.h>

typedef struct rd_kafka {
	int dummy;
} rd_kafka_t;

typedef struct rd_kafka_topic {
	int dummy;
} rd_kafka_topic_t;

typedef struct rd_kafka_metadata {
        int         broker_cnt;     /* Number of brokers in 'brokers' */
        struct rd_kafka_metadata_broker *brokers;  /* Brokers */

        int         topic_cnt;      /* Number of topics in 'topics' */
        struct rd_kafka_metadata_topic *topics;    /* Topics */

        int32_t     orig_broker_id; /* Broker originating this metadata */
        char       *orig_broker_name; /* Name of originating broker */
} rd_kafka_metadata_t;

rd_kafka_metadata (rd_kafka_t *rk, int all_topics,
                   rd_kafka_topic_t *only_rkt,
                   const struct rd_kafka_metadata **metadatap,
                   int timeout_ms);
C",
q"D
extern (C):

struct rd_kafka
{
    int dummy;
}

alias rd_kafka_t = rd_kafka;

struct rd_kafka_topic
{
    int dummy;
}

alias rd_kafka_topic_t = rd_kafka_topic;

struct rd_kafka_metadata_
{
    int broker_cnt; /* Number of brokers in 'brokers' */
    struct rd_kafka_metadata_broker;
    rd_kafka_metadata_broker* brokers; /* Brokers */

    int topic_cnt; /* Number of topics in 'topics' */
    struct rd_kafka_metadata_topic;
    rd_kafka_metadata_topic* topics; /* Topics */

    int orig_broker_id; /* Broker originating this metadata */
    char* orig_broker_name; /* Name of originating broker */
}

alias rd_kafka_metadata_t = rd_kafka_metadata_;

int rd_kafka_metadata (
    rd_kafka_t* rk,
    int all_topics,
    rd_kafka_topic_t* only_rkt,
    const(rd_kafka_metadata_*)* metadatap,
    int timeout_ms);
D");

}
