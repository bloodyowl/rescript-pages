open Test

let fileExists = (~message=?, filePath) =>
  assertion(
    ~message?,
    ~operator="fileExists",
    (a, b) => a == b,
    NodeJs.Fs.existsSync(filePath),
    true,
  )
let fileContains = (~message=?, filePath, contents) =>
  assertion(
    ~message?,
    ~operator="fileContains",
    (a, b) => a->Js.String2.includes(b),
    NodeJs.Fs.readFileSync(filePath)->NodeJs.Buffer.toStringWithEncoding(
      NodeJs.StringEncoding.utf8,
    ),
    contents,
  )

test("Generates sitemap", () => {
  fileExists(NodeJs.Path.join([NodeJs.Process.process->NodeJs.Process.cwd, "dist/sitemap.xml"]))
  fileContains(
    NodeJs.Path.join([NodeJs.Process.process->NodeJs.Process.cwd, "dist/sitemap.xml"]),
    "https://bloodyowl.github.io/rescript-pages/",
  )
  fileContains(
    NodeJs.Path.join([NodeJs.Process.process->NodeJs.Process.cwd, "dist/sitemap.xml"]),
    "https://bloodyowl.github.io/rescript-pages/404.html",
  )
  fileContains(
    NodeJs.Path.join([NodeJs.Process.process->NodeJs.Process.cwd, "dist/sitemap.xml"]),
    "https://bloodyowl.github.io/rescript-pages/docs/getting-started",
  )
})

test("Copies statics", () => {
  fileContains(
    NodeJs.Path.join([NodeJs.Process.process->NodeJs.Process.cwd, "dist/some-file.txt"]),
    "Hello world",
  )
})

test("Adds information to page", () => {
  fileContains(
    ~message="Title",
    NodeJs.Path.join([NodeJs.Process.process->NodeJs.Process.cwd, "dist/index.html"]),
    `<title data-react-helmet="true">`,
  )
  fileContains(
    ~message="Charset",
    NodeJs.Path.join([NodeJs.Process.process->NodeJs.Process.cwd, "dist/index.html"]),
    `<meta data-react-helmet="true" charset="UTF-8"/>`,
  )
  fileContains(
    ~message="Styles",
    NodeJs.Path.join([NodeJs.Process.process->NodeJs.Process.cwd, "dist/index.html"]),
    `data-emotion="rpcss`,
  )
  fileContains(
    ~message="Styles",
    NodeJs.Path.join([NodeJs.Process.process->NodeJs.Process.cwd, "dist/index.html"]),
    `class="rpcss-`,
  )
  fileContains(
    ~message="Initial data",
    NodeJs.Path.join([NodeJs.Process.process->NodeJs.Process.cwd, "dist/index.html"]),
    `id="initialData"`,
  )
})

test("Handles redirects", () => {
  fileExists(
    NodeJs.Path.join([NodeJs.Process.process->NodeJs.Process.cwd, "dist/old_url/index.html"]),
  )
  fileContains(
    NodeJs.Path.join([NodeJs.Process.process->NodeJs.Process.cwd, "dist/old_url/index.html"]),
    `URL=new_url`,
  )
})
