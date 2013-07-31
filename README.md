SWF-Preloader
=============

Flash app that loads self-contained Flash apps and animations in the SWF Activity Module for Moodle 2.5+

Developed and built using the free and open source FlashDevelop
ActionScript and Apache Flex IDE. See: http://www.flashdevelop.org/
There isn't a decent Actionscript IDE for Linux yet. Sorry!

Works with the SWF Activity Module for Moodle. See: https://github.com/matbury/SWF-Activity-Module2.5

Set the compiler output to your Moodle's /mod/swf/swfs/ directory.
e.g. C:\\wamp\public_html\moodle\mod\swf\swfs\preloader.swf

Functions:

* Loads and runs SWF files.
* Enables users to reposition loaded SWFs.
* Catches some Actionscript runtime errors and displays them.
* Warns users when their server session is about to expire (session timeout).
* Catches grade events to relay grades from loaded SWFs to Moodle's grade book.