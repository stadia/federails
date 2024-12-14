{% capture version_path %}{% unless page.version == "*" %}/versions/{{ page.version }}{% endunless %}{% endcapture %}
{%- assign kept = include.path | kept_reference_path? -%}
{%- if include.path and kept %}
{%- capture url %}{{ site.baseurl }}{{ version_path | strip }}/reference/{{ include.path }}{% endcapture -%}
<a href="{{ url }}">{{ include.label | mute_namespace }}</a>
{%- else -%}
<small class="text-grey-dk-000">{{- include.label -}}</small>
{%- endif -%}
