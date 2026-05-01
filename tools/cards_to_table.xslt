<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
  <xsl:output method="html" encoding="UTF-8" indent="yes"/>

  <xsl:template match="/cards">
    <html>
      <head>
        <meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>
        <title>New York Mafia — Cards Database</title>
        <style>
          body{font-family:Arial,Helvetica,sans-serif;padding:16px}
          table{border-collapse:collapse;width:100%;margin-bottom:24px}
          th,td{border:1px solid #ddd;padding:6px;text-align:left;vertical-align:top}
          th{background:#f4f4f4}
          h1,h2{font-weight:600}
          .filters{margin-bottom:8px}
          .filters select{margin-right:8px;margin-bottom:8px}
          img.preview { max-width: 80px; max-height: 80px; border: 1px solid #ccc; }
        </style>
        <!-- Retained JS filtering logic from Gnarl -->
        <script>
          document.addEventListener('DOMContentLoaded', function(){
            document.querySelectorAll('table.filterable').forEach(function(table){
              var rows = Array.from(table.querySelectorAll('tr')).slice(1);
              var filtersDiv = table.previousElementSibling &amp;&amp; table.previousElementSibling.classList.contains('filters') ? table.previousElementSibling : null;
              if(!filtersDiv) return;
              var colClasses = new Set();
              rows.forEach(function(r){ r.querySelectorAll('td').forEach(function(td){ td.classList.forEach(function(c){ if(c.indexOf('col-')===0) colClasses.add(c); }); }); });
              colClasses.forEach(function(colClass){
                var select = document.createElement('select');
                select.dataset.col = colClass;
                var opt = document.createElement('option'); opt.value=''; opt.text='All '+colClass.replace('col-',''); select.appendChild(opt);
                var values = new Set();
                table.querySelectorAll('td.'+colClass).forEach(function(td){ values.add(td.textContent.trim()); });
                Array.from(values).sort().forEach(function(v){ var o=document.createElement('option'); o.value=v; o.text=v; select.appendChild(o); });
                select.addEventListener('change', function(){
                  var selVals = {};
                  filtersDiv.querySelectorAll('select').forEach(function(s){ if(s.value) selVals[s.dataset.col]=s.value; });
                  rows.forEach(function(row){
                    var show = true;
                    Object.keys(selVals).forEach(function(cc){
                      var cell = row.querySelector('td.'+cc);
                      var val = cell?cell.textContent.trim():'';
                      if(val !== selVals[cc]) show = false;
                    });
                    row.style.display = show ? '' : 'none';
                  });
                });
                filtersDiv.appendChild(select);
              });
            });
          });
        </script>
      </head>
      <body>
        <h1>New York Mafia — Cards Database</h1>

        <!-- Events Table -->
        <h2>Events (Události)</h2>
        <div class="filters"></div>
        <table class="filterable">
          <tr>
            <th>ID</th><th>Count</th><th>Name</th><th>Text</th><th>Type</th><th>Image Preview</th>
          </tr>
          <xsl:for-each select="card[event]">
            <tr>
              <td><xsl:value-of select="@id"/></td>
              <td>
                <xsl:choose>
                  <xsl:when test="@count"><xsl:value-of select="@count"/></xsl:when>
                  <xsl:otherwise>1</xsl:otherwise>
                </xsl:choose>
              </td>
              <td><xsl:value-of select="name"/></td>
              <td><xsl:value-of select="text"/></td>
              <td class="col-type"><xsl:value-of select="event/@type"/></td>
              <td>
                <xsl:if test="string-length(event/@image) &gt; 0">
                  <img class="preview">
                    <xsl:attribute name="src"><xsl:value-of select="event/@image"/></xsl:attribute>
                  </img>
                </xsl:if>
              </td>
            </tr>
          </xsl:for-each>
        </table>

        <!-- Goals Table -->
        <h2>Goals (Herní cíle)</h2>
        <div class="filters"></div>
        <table class="filterable">
          <tr>
            <th>ID</th><th>Count</th><th>Name</th><th>Subtitle</th><th>Text</th><th>Points</th><th>Image Preview</th>
          </tr>
          <xsl:for-each select="card[goal]">
            <tr>
              <td><xsl:value-of select="@id"/></td>
              <td>
                <xsl:choose>
                  <xsl:when test="@count"><xsl:value-of select="@count"/></xsl:when>
                  <xsl:otherwise>1</xsl:otherwise>
                </xsl:choose>
              </td>
              <td><xsl:value-of select="name"/></td>
              <td class="col-subtitle"><xsl:value-of select="subtitle"/></td>
              <td><xsl:value-of select="text"/></td>
              <td class="col-points"><xsl:value-of select="goal/@points"/></td>
              <td>
                <xsl:if test="string-length(goal/@image) &gt; 0">
                  <img class="preview">
                    <xsl:attribute name="src"><xsl:value-of select="goal/@image"/></xsl:attribute>
                  </img>
                </xsl:if>
              </td>
            </tr>
          </xsl:for-each>
        </table>

      </body>
    </html>
  </xsl:template>
</xsl:stylesheet>