<?xml version="1.0" encoding="UTF-8"?>
<iso:schema xmlns="http://purl.oclc.org/dsdl/schematron" 
            xmlns:iso="http://purl.oclc.org/dsdl/schematron" 
            xmlns:sch="http://www.ascc.net/xml/schematron"
            queryBinding="xslt2"
            schemaVersion="ISO19757-3">
  <iso:title>Minimal Schematron check</iso:title>

  <iso:pattern >
    <iso:rule context="ead">
      <iso:assert test="eadheader">EAD record should have a header</iso:assert>
      <iso:report test="count(eadheader)">
      <iso:value-of select="count(eadheader)"/> headers</iso:report>
    </iso:rule>
  </iso:pattern>

</iso:schema>
