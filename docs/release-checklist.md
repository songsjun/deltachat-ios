# Release checklist

on the command-line:

1. update core rust submodule, if needed:
   $ ./tools/update-core.sh
   depending on how much you trust in rust, you might want to do a
   ./tools/clean-core.sh before building

2. update translations:
   $ ./tools/tx-pull-translations.sh

3. update local help:
   $ cd ../deltachat-pages; ./tools/create-local-help.py; cd ../deltachat-ios

4. update CHANGELOG.md
   (the core-changelog at
   https://github.com/deltachat/deltachat-core-rust/blob/master/CHANGELOG.md
   and the "N commits to master since last release" on
   https://github.com/deltachat/deltachat-ios/releases gives some good hints)

in Xcode:

5. a) adapt version ("View/Navigator/Project Navigator/deltachat-ios",
      target "deltachat-ios", then "General/Version")
   b) increase the build number in the same dialog

6. a) select "Generic iOS Device" in the toolbar
   b) select menu "Product/Archive"
      (codesign may ask for a password, this _may_ be empty and "Enter" will do)
   c) on success, a dialog with all releases on the machine is shown;
      select the most recent, then "Distribute/App Store Connect/Next/Upload",
      leave default options (strip symbols: yes, upload symbols: yes,
      automatically manage signing: yes), in the summary, click "Upload" again

on https://appstoreconnect.apple.com :

7. for a **Testflight release**, open "My Apps/Delta Chat/TestFlight/iOS"
   a) fill out compliance info, status should be "Ready to Submit" then
   b) select "open-testing-group" on the left, then "Builds" tab
   c) click "+" and select the version made "Ready to submit" above
   d) make sure the credentials shown on the next page are working
      (the credentials are needed by apple for review)

   OR

8. for a **Reguar release**, open "My Apps/Delta Chat/+Version or Platform/iOS"
   a) enter the version number (without leading "v")
   b) fill out "what's new", use CHANGELOG.md as a template
   c) make sure, the credentials for the apple-review-team are working
   click on "Save" and then "Submit", wrt ads: we do not use ads, answer "No"

in both cases, make sure, the provided test-email-address is working.
finally, back on command line:

9. commit changes from 1.-5. add add a tag:
   $ git tag v1.2.3; git push --tags
