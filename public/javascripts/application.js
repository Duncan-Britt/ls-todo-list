$(document).ready(function() {
  $("form.delete").on('submit', function() {
    return confirm("Are you sure you want to delete this list item?");
  });
});
