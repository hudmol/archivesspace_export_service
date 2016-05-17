Xalan
-----

We have bundled Xalan 2.7.2 here (serializer.jar, xalan.jar,
xercesImpl.jar, xml-apis.jar).

We use a custom version of Xalan here to allow the `xml_cleaner.rb`
helper to find and catch XML parse errors.  At the time of writing,
the version of Xalan that ships with the JVM doesn't give line or
column numbers for the errors it finds, so we pull in a newer version
of Xalan for this.
