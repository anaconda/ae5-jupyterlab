define(['base/js/namespace', 'contents'], function(Jupyter, Contents){
  // TODO: Should we consider *not* making links open in the same tab? This
  // makes it annoying to navigate back to the notebook server landing page.
  // Make links open in the same tab instead of a new tab
  // http://jupyter-notebook.readthedocs.io/en/latest/public_server.html#embedding-the-notebook-in-another-website

  Jupyter._target = '_self';
  $('#refresh_running_list').click();
  window.cont = Contents;

  // TODO: Document what this is actually doing.
  // when viewing clasic, reset the dashboard link (`default_url` changes too much stuff)
  var dashboardLink = $('#ipython_notebook > a:first-child');
  dashboardLink.attr(
    'href',
    dashboardLink.attr('href').replace(/\/lab$/, '/tree')
  );
});
