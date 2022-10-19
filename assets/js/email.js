let email = [
  "s",
  "@",
  "s",
  "h",
  "u",
  "m",
  "p",
  "h",
  "r",
  "i",
  "e",
  "s",
  ".",
  "c",
  "a",
].join("");

let a = document.createElement("a");

a.setAttribute("href", `mailto:${email}`);
a.innerHTML = email;

document.querySelector("#email").replaceWith(a);
