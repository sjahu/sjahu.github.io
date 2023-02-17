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

let a = document.querySelector("#email a");
a.addEventListener("click", () => location.href = `mailto:${email}`);

let style = document.createElement("style");
style.textContent = `#email::before { content: " at "; }\n#email a::after { content: "${email}"; }`;
document.head.append(style);
