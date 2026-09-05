---
title: "Stats"
date: 2026-09-05
draft: false
description: "Build-time aggregated stats (privacy-safe) — shell usage and GitHub contributions."
---

This page shows **build-time generated**, privacy-safe aggregated stats. No raw commands, paths, or hosts are exposed — only base command counts and public GitHub contributions. Data is generated at build via `scripts/export-atuin-stats.sh` and `scripts/fetch-github-stats.mjs`.

<div id="stats-root">
  <h2>Shell Usage (Atuin)</h2>
  <p id="atuin-meta">Loading…</p>

  <table id="atuin-top-table" style="width:100%;border-collapse:collapse;">
    <thead><tr><th style="text-align:left;border-bottom:1px solid #ccc;">Command</th><th style="text-align:right;border-bottom:1px solid #ccc;">Count</th></tr></thead>
    <tbody><tr><td colspan="2">Loading…</td></tr></tbody>
  </table>

  <canvas id="atuin-chart" width="800" height="300" style="max-width:100%;margin:1em 0;"></canvas>

  <table id="atuin-perday-table" style="width:100%;border-collapse:collapse;margin-top:1em;">
    <thead><tr><th style="text-align:left;border-bottom:1px solid #ccc;">Date</th><th style="text-align:right;border-bottom:1px solid #ccc;">Count</th></tr></thead>
    <tbody><tr><td colspan="2">Loading…</td></tr></tbody>
  </table>

  <p id="atuin-privacy" style="font-size:0.85em;color:#666;"></p>

  <h2>GitHub Contributions</h2>
  <p id="github-meta">Loading…</p>

  <table id="github-pr-table" style="width:100%;border-collapse:collapse;">
    <thead><tr><th style="text-align:left;border-bottom:1px solid #ccc;">PR</th><th style="text-align:left;border-bottom:1px solid #ccc;">State</th><th style="text-align:left;border-bottom:1px solid #ccc;">Date</th></tr></thead>
    <tbody><tr><td colspan="3">Loading…</td></tr></tbody>
  </table>

  <canvas id="github-chart" width="800" height="200" style="max-width:100%;margin:1em 0;"></canvas>

  <p id="github-privacy" style="font-size:0.85em;color:#666;"></p>

  <noscript>
    <p><em>JavaScript is disabled — tables above will not populate dynamically. You can view raw JSON at <a href="/data/atuin.json">/data/atuin.json</a> and <a href="/data/github.json">/data/github.json</a>.</em></p>
  </noscript>
</div>

<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js"></script>
<script>
(function() {
  function fetchJSON(url) { return fetch(url).then(function(r){ if(!r.ok) throw new Error(r.statusText); return r.json(); }); }

  function renderAtuin(data) {
    var meta = document.getElementById('atuin-meta');
    meta.textContent = 'Total: ' + data.total_commands + ' | Unique base commands: ' + data.unique_commands + ' | Generated: ' + data.generated_at;
    var tbody = document.querySelector('#atuin-top-table tbody');
    tbody.innerHTML = '';
    (data.top_commands||[]).forEach(function(row){
      var tr=document.createElement('tr');
      tr.innerHTML='<td style="padding:4px 8px;border-bottom:1px solid #eee;">'+row.command+'</td><td style="padding:4px 8px;border-bottom:1px solid #eee;text-align:right;">'+row.count+'</td>';
      tbody.appendChild(tr);
    });
    var perTbody=document.querySelector('#atuin-perday-table tbody');
    perTbody.innerHTML='';
    (data.per_day||[]).forEach(function(row){
      if(row.count===0) return; // keep table compact
      var tr=document.createElement('tr');
      tr.innerHTML='<td style="padding:4px 8px;border-bottom:1px solid #eee;">'+row.date+'</td><td style="padding:4px 8px;border-bottom:1px solid #eee;text-align:right;">'+row.count+'</td>';
      perTbody.appendChild(tr);
    });
    if(perTbody.children.length===0) perTbody.innerHTML='<tr><td colspan="2">No activity in last 60 days (or sample data sparsely populated).</td></tr>';
    document.getElementById('atuin-privacy').textContent = data.privacy_notes||'';

    // Chart
    try {
      var ctx=document.getElementById('atuin-chart');
      if(ctx && window.Chart) {
        var labels=(data.per_day||[]).map(function(d){return d.date;});
        var counts=(data.per_day||[]).map(function(d){return d.count;});
        new Chart(ctx, {type:'bar', data:{labels:labels, datasets:[{label:'Commands per day (60d)', data:counts, backgroundColor:'#36a2eb'}]}, options:{responsive:true, plugins:{legend:{display:false}}, scales:{x:{ticks:{maxTicksLimit:12}}, y:{beginAtZero:true}}}});
      }
    } catch(e){ console.error(e); }
  }

  function renderGithub(data) {
    var meta=document.getElementById('github-meta');
    meta.textContent='User: '+(data.user||'')+' | Commits (365d): '+(data.totalCommitContributions||0)+' | PRs: '+(data.totalPullRequestContributions||0)+' | Generated: '+data.generated_at;
    var tbody=document.querySelector('#github-pr-table tbody');
    tbody.innerHTML='';
    (data.pullRequests||[]).forEach(function(pr){
      var tr=document.createElement('tr');
      var d=new Date(pr.createdAt).toISOString().slice(0,10);
      tr.innerHTML='<td style="padding:4px 8px;border-bottom:1px solid #eee;"><a href="'+pr.url+'">'+pr.title+'</a></td><td style="padding:4px 8px;border-bottom:1px solid #eee;">'+pr.state+'</td><td style="padding:4px 8px;border-bottom:1px solid #eee;">'+d+'</td>';
      tbody.appendChild(tr);
    });
    if(!tbody.children.length) tbody.innerHTML='<tr><td colspan="3">No recent PRs.</td></tr>';
    document.getElementById('github-privacy').textContent=data.privacy_notes||'';
    try {
      var ctx=document.getElementById('github-chart');
      if(ctx && window.Chart) {
        var weeks=data.weeks||[];
        var labels=weeks.map(function(w){return w.date;});
        var counts=weeks.map(function(w){return w.count;});
        var colors=weeks.map(function(w){return w.color||'#9be9a8';});
        new Chart(ctx, {type:'bar', data:{labels:labels, datasets:[{label:'Contributions per week', data:counts, backgroundColor:colors}]}, options:{responsive:true, plugins:{legend:{display:false}}, scales:{x:{ticks:{maxTicksLimit:12}}, y:{beginAtZero:true}}}});
      }
    } catch(e){ console.error(e); }
  }

  fetchJSON('/data/atuin.json').then(renderAtuin).catch(function(e){ document.getElementById('atuin-meta').textContent='Failed to load atuin.json: '+e.message; });
  fetchJSON('/data/github.json').then(renderGithub).catch(function(e){ document.getElementById('github-meta').textContent='Failed to load github.json: '+e.message; });
})();
</script>
