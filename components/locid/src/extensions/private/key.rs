// This file is part of ICU4X. For terms of use, please see the file
// called LICENSE at the top level of the ICU4X source tree
// (online at: https://github.com/unicode-org/icu4x/blob/main/LICENSE ).

impl_tinystr_subtag!(
    /// A single item used in a list of [`Private`](super::Private) extensions.
    ///
    /// The key has to be an ASCII alphanumerical string no shorter than
    /// one character and no longer than eight.
    ///
    /// # Examples
    ///
    /// ```
    /// use icu::locid::extensions::private::Key;
    ///
    /// let key1: Key = "Foo".parse().expect("Failed to parse a Key.");
    ///
    /// assert_eq!(key1.as_str(), "foo");
    /// ```
    Key,
    extensions::private::Key,
    extensions_private_key,
    1..=8,
    s,
    s.is_ascii_alphanumeric(),
    s.to_ascii_lowercase(),
    s.is_ascii_alphanumeric() && s.is_ascii_lowercase(),
    InvalidExtension,
    ["foo12"],
    ["toolooong"],
);
