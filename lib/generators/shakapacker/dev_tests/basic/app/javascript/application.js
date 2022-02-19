var counter = document.getElementById("counter"),
    incrButton = document.getElementById("increase"),
    decrButton = document.getElementById("decrease");

var initiateCounter = 0;
counter.innerHTML = initiateCounter;

incrButton.addEventListener("click", function(e) {
  e.preventDefault();
  counter.innerHTML++;
}, false);

decrButton.addEventListener("click", function(e) {
  e.preventDefault();
  counter.innerHTML--;
}, false);
