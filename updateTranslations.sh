#!/bin/bash

# This script pulls android translations from transifex and converts them to apple strings files. 
# Credits to Daniel Cohen Gindi.


# ----Main-----

TMP_ANDROID_TRANSLATIONS=tmpAndroidTranslations

# check global vars
if [[ -z `which node` ]] 
then
    echo "ERROR: You need to have node installed. Exiting."
    exit 
fi

if [[ -z `which tx` ]] 
then
    echo "ERROR: You need to have tx installed. Exiting."
    exit 
fi

if [[ -d $TMP_ANDROID_TRANSLATIONS ]] 
then 
    rm -rf $TMP_ANDROID_TRANSLATIONS
fi

IOS_TRANSLATIONS=( $(find . -name Localizable.strings) )

# create folders for each resource 
mkdir $TMP_ANDROID_TRANSLATIONS
cd $TMP_ANDROID_TRANSLATIONS
tx pull --all --source
cd ..
for (( i=0; i<${#IOS_TRANSLATIONS[@]}; i++ )) {
    LANG_DIR=`echo ${IOS_TRANSLATIONS[i]} | cut -d "." -f2 | cut -c 2-`
    echo "convertTranslations: $TMP_ANDROID_TRANSLATIONS/$LANG_DIR/strings.xml -> ${IOS_TRANSLATIONS[i]}"
    if [[ $LANG_DIR == "en" && -f untranslated.xml ]] 
    then
        node convertTranslations.js $TMP_ANDROID_TRANSLATIONS/$LANG_DIR/strings.xml untranslated.xml ${IOS_TRANSLATIONS[i]}
    else 
        node convertTranslations.js $TMP_ANDROID_TRANSLATIONS/$LANG_DIR/strings.xml ${IOS_TRANSLATIONS[i]}
    fi
}

rm -rf $TMP_ANDROID_TRANSLATIONS
