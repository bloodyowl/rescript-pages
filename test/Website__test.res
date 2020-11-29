open Test

let fileExists = (~message=?, filePath) => assertion(~message?, ~operator="fileExists", (a, b) => a == b, Node.Fs.existsSync(filePath), true)
let fileContains = (~message=?, filePath, contents) => assertion(~message?, ~operator="fileExists", (a, b) => a->Js.String2.includes(b), Node.Fs.readFileSync(filePath, #utf8), contents)

test("Generates sitemap", () => {
  fileExists(Node.Path.join([Node.Process.cwd(), "dist/sitemap.xml"]))
  fileContains(Node.Path.join([Node.Process.cwd(), "dist/sitemap.xml"]), "https://bloodyowl.github.io/rescript-pages/")
  fileContains(Node.Path.join([Node.Process.cwd(), "dist/sitemap.xml"]), "https://bloodyowl.github.io/rescript-pages/404.html")
  fileContains(Node.Path.join([Node.Process.cwd(), "dist/sitemap.xml"]), "https://bloodyowl.github.io/rescript-pages/docs/getting-started")
})

test("Copies statics", () => {
  fileContains(Node.Path.join([Node.Process.cwd(), "dist/some-file.txt"]), "Hello world")
})

test("Adds information to page", () => {
  fileContains(~message="Title", Node.Path.join([Node.Process.cwd(), "dist/index.html"]), `<title data-react-helmet="true">`)
  fileContains(~message="Charset", Node.Path.join([Node.Process.cwd(), "dist/index.html"]), `<meta data-react-helmet="true" charset="UTF-8"/>`)
  fileContains(~message="Styles", Node.Path.join([Node.Process.cwd(), "dist/index.html"]), `data-emotion-rpcss`)
  fileContains(~message="Initial data", Node.Path.join([Node.Process.cwd(), "dist/index.html"]), `id="initialData"`)
})


test("Handles redirects", () => {
  fileExists(Node.Path.join([Node.Process.cwd(), "dist/old_url/index.html"]))
  fileContains(Node.Path.join([Node.Process.cwd(), "dist/old_url/index.html"]), `URL=new_url`)
})