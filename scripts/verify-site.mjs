import fs from "node:fs";
import path from "node:path";
import vm from "node:vm";

const requiredFiles = [
  "index.html",
  "login/index.html",
  "account/index.html",
  "workspace/index.html",
  "workspace/studio/index.html",
  "previews/index.html",
  "marketplace/index.html",
  "_headers",
];
const failures = [];
for (const file of requiredFiles) {
  if (!fs.existsSync(file)) failures.push(`Missing required route/file: ${file}`);
}
if (failures.length) {
  console.error(failures.join("\n"));
  process.exit(1);
}

const read = file => fs.readFileSync(file, "utf8");
const home = read("index.html");
const login = read("login/index.html");
const account = read("account/index.html");
const workspace = read("workspace/index.html");
const studio = read("workspace/studio/index.html");

function assert(condition, message) {
  if (!condition) failures.push(message);
}
assert((home.match(/href="\/login\//g) || []).length === 1, "Home page must have exactly one private login link.");
for (const route of ["/previews/", "/marketplace/", "/account/", "/login/"]) {
  assert(home.includes(`href="${route}"`), `Home navigation missing ${route}`);
}
assert(account.includes('id="newPasswordForm"'), "Customer account is missing the password recovery form.");
assert(account.includes('PASSWORD_RECOVERY'), "Customer account must handle Supabase PASSWORD_RECOVERY.");
assert(account.includes('updateUser({password:p})'), "Customer account must submit the new password to Supabase.");
assert(account.includes('emailRedirectTo:location.origin+"/account/?confirmed=1"'), "Customer signup must return to the confirmation page.");
assert(login.includes('redirectTo:location.origin+"/account/?reset=1"'), "Private login password reset must return to the recovery page.");
assert(login.includes('emailRedirectTo:location.origin+"/login/?confirmed=1"'), "Workspace-access request confirmation redirect missing.");
assert(workspace.includes('from("workspace_members")'), "Workspace route must check membership.");
assert(workspace.includes('location.replace("/login/")'), "Workspace route must redirect unauthenticated users.");
assert(studio.includes('from("workspace_members")'), "Studio route must check membership.");
assert(studio.includes('location.replace("/login/")'), "Studio route must redirect unauthenticated users.");

for (const file of requiredFiles.filter(f => f.endsWith(".html"))) {
  const html = read(file);
  const inlineScripts = [...html.matchAll(/<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/gi)];
  for (let i = 0; i < inlineScripts.length; i++) {
    try {
      new vm.Script(inlineScripts[i][1], { filename: `${file}#inline-script-${i + 1}` });
    } catch (error) {
      failures.push(`JavaScript syntax error in ${file} inline script ${i + 1}: ${error.message}`);
    }
  }
}

if (failures.length) {
  console.error("Site foundation verification FAILED:");
  for (const failure of failures) console.error(`- ${failure}`);
  process.exit(1);
}
console.log("Site foundation verification passed.");
console.log(`Checked ${requiredFiles.length} required files/routes, navigation, account recovery, membership guards, and inline JavaScript syntax.`);
