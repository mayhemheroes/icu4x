``list::ffi``
=============

.. cpp:class:: ICU4XList

    A list of strings


    .. cpp:function:: static ICU4XList create()

        Create a new list of strings


    .. cpp:function:: static ICU4XList create_with_capacity(size_t capacity)

        Create a new list of strings with preallocated space to hold at least ``capacity`` elements


    .. cpp:function:: void push(const std::string_view val)

        Push a string to the list

        For C++ users, potentially invalid UTF8 will be handled via REPLACEMENT CHARACTERs


    .. cpp:function:: size_t len() const

        The number of elements in this list


.. cpp:class:: ICU4XListFormatter

    See the `Rust documentation for ListFormatter <https://unicode-org.github.io/icu4x-docs/doc/icu/list/struct.ListFormatter.html>`__ for more information.


    .. cpp:function:: static diplomat::result<ICU4XListFormatter, ICU4XError> create_and_with_style(const ICU4XDataProvider& provider, const ICU4XLocale& locale, ICU4XListStyle style)

        Construct a new ICU4XListFormatter instance for And patterns

        See the `Rust documentation for try_new_and_unstable <https://unicode-org.github.io/icu4x-docs/doc/icu/normalizer/struct.ListFormatter.html#method.try_new_and_unstable>`__ for more information.


    .. cpp:function:: static diplomat::result<ICU4XListFormatter, ICU4XError> create_or_with_style(const ICU4XDataProvider& provider, const ICU4XLocale& locale, ICU4XListStyle style)

        Construct a new ICU4XListFormatter instance for And patterns

        See the `Rust documentation for try_new_or_unstable <https://unicode-org.github.io/icu4x-docs/doc/icu/normalizer/struct.ListFormatter.html#method.try_new_or_unstable>`__ for more information.


    .. cpp:function:: static diplomat::result<ICU4XListFormatter, ICU4XError> create_unit_with_style(const ICU4XDataProvider& provider, const ICU4XLocale& locale, ICU4XListStyle style)

        Construct a new ICU4XListFormatter instance for And patterns

        See the `Rust documentation for try_new_unit_unstable <https://unicode-org.github.io/icu4x-docs/doc/icu/normalizer/struct.ListFormatter.html#method.try_new_unit_unstable>`__ for more information.


    .. cpp:function:: template<typename W> diplomat::result<std::monostate, ICU4XError> format_to_writeable(const ICU4XList& list, W& write) const

        See the `Rust documentation for format <https://unicode-org.github.io/icu4x-docs/doc/icu/normalizer/struct.ListFormatter.html#method.format>`__ for more information.


    .. cpp:function:: diplomat::result<std::string, ICU4XError> format(const ICU4XList& list) const

        See the `Rust documentation for format <https://unicode-org.github.io/icu4x-docs/doc/icu/normalizer/struct.ListFormatter.html#method.format>`__ for more information.


.. cpp:enum-struct:: ICU4XListStyle

    See the `Rust documentation for ListStyle <https://unicode-org.github.io/icu4x-docs/doc/icu/list/enum.ListStyle.html>`__ for more information.


    .. cpp:enumerator:: Wide

    .. cpp:enumerator:: Short

    .. cpp:enumerator:: Narrow
