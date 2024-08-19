---
layout: archives
title: Blog
permalink: /blog/
---
<div class="pagination">
  {% if site.pagination.previous_page %}
    <a href="{{ site.pagination.previous_page_path | relative_url }}" class="previous">Previous</a>
  {% endif %}
  <span class="page_number ">Page: {{ site.pagination.page }} of {{ site.pagination.total_pages }}</span>
  {% if site.pagination.next_page %}
    <a href="{{ site.pagination.next_page_path | relative_url }}" class="next">Next</a>
  {% endif %}
</div>

