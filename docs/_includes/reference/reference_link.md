{% capture version_path %}{% unless page.version == "*" %}/versions/{{ page.version }}{% endunless %}{% endcapture %}
{%- if include.path %}
{%- capture url %}{{ site.baseurl }}{{ version_path | strip }}/reference/{{ include.path }}{% endcapture -%}
<a href="{{ url }}">{{ include.label | mute_namespace }}</a>
{%- else -%}
{{ include.label -}}
{% endif -%}
