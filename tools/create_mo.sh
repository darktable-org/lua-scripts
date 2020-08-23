#!/bin/bash
for i in `cat LINGUAS`; do msgcat --unique $i/*po -o ../../locale/$i/LC_MESSAGES/scripts.po ; msgfmt ../../locale/$i/LC_MESSAGES/scripts.po -o ../../locale/$i/LC_MESSAGES/scripts.mo ; rm ../../locale/$i/LC_MESSAGES/scripts.po ; done
