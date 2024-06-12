#!/bin/bash

sed -i -re "s/(#)?default_transaction_read_only = off/default_transaction_read_only = on/" /var/lib/postgresql/data/postgresql.conf;
