#!/bin/bash

if [[ -e /dev/snd ]]; then
	exec apulse librewolf "$@"
else
	exec librewolf "$@"
fi