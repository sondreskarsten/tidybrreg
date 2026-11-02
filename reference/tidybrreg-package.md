# tidybrreg: Tidy Access to Norway's Business Registry ('Enhetsregisteret')

A tidy interface to query and download data from the Norwegian Central
Coordinating Register for Legal Entities (Enhetsregisteret), maintained
by the Brønnøysund Register Centre. Looks up entities, sub-entities,
roles, corporate groups and signing authority, searches the register,
reads the change data capture feeds, and downloads the bulk register.
Returns tibbles with English column names mapped via a data-driven
dictionary; unknown API fields pass through with auto-generated names,
and only observed fields are emitted. Coded values (legal forms,
industry codes, roles) can be translated to English or Norwegian using
bundled reference data or live lookups from the Statistics Norway
'KLASS' API. Register data is published under the Norwegian Licence for
Open Government Data (NLOD 2.0).

## See also

Useful links:

- <https://sondreskarsten.github.io/tidybrreg/>

- <https://github.com/sondreskarsten/tidybrreg>

- Report bugs at <https://github.com/sondreskarsten/tidybrreg/issues>

## Author

**Maintainer**: Sondre Skarsten <sondreskarsten@gmail.com>
