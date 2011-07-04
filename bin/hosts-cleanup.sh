#!/bin/bash

PREFIX="$1"
rm  -f ${PREFIX}fs/var/awstats/data/*
rm -rf ${PREFIX}fs/var/collectd/*
rm -rf ${PREFIX}fs/var/symon/rrds/*
rm -rf ${PREFIX}fs/var/ganglia/rrds/*
rm -rf ${PREFIX}fs/var/mail/virtual/*

### Usage:
# $0 '/var/backup/*/2011-06-*/'
