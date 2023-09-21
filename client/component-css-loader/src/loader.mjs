import * as path from "node:path";
import * as vm from "node:vm";

import { default as resolve } from "resolve";

class ImportNameFactory {
  #current = 0;

  next() {
    return `__COMPONENT_CSS_LOADER__${(this.#current++).toString(10)}__`;
  }
}

const resolveAsync = async (id, opts) =>
  new Promise((accept, reject) =>
    resolve(id, opts, (err, res) => {
      if (err) {
        reject(err);
      } else {
        accept(res);
      }
    }),
  );

const loadModule = async (loaderContext, filename) => {
  return new Promise((resolve, reject) => {
    loaderContext.loadModule(filename, (error, source, sourceMap, module) => {
      if (error) {
        reject(error);
      } else {
        resolve({ filename, source, sourceMap, module });
      }
    });
  });
};

const extractQueryFromPath = (path) => {
  const indexOfLastExclMark = path.lastIndexOf("!");
  const indexOfQuery = path.lastIndexOf("?");
  return indexOfQuery !== -1 && indexOfQuery > indexOfLastExclMark
    ? {
        relativePathWithoutQuery: path.slice(0, indexOfQuery),
        query: path.slice(indexOfQuery),
      }
    : {
        relativePathWithoutQuery: path,
        query: "",
      };
};

const splitRelativePath = (path) => {
  const { relativePathWithoutQuery, query } = extractQueryFromPath(path);
  const indexOfLastExclMark = relativePathWithoutQuery.lastIndexOf("!");
  const loaders = path.slice(0, indexOfLastExclMark + 1);
  const relativePath = relativePathWithoutQuery.slice(indexOfLastExclMark + 1);
  return { loaders, relativePath, query };
};

const evalDependencyGraph = async ({
  importNameFactory,
  loaderContext,
  src,
  filename,
  publicPath = "",
}) => {
  const moduleCache = new Map();
  const cache = (key, value) => {
    moduleCache.set(key, value);
    return value;
  };

  const imports = [];
  const importFor = (path) => {
    const importName = importNameFactory.next();
    imports.push({
      path,
      importName,
    });
    return importName;
  };
  class ImportUrl {
    #importName;
    constructor(path, _) {
      this.#importName = `\${unsafeCSS(${importFor(path)})}`;
    }
    toString() {
      return this.#importName;
    }
  }

  const exports = {};
  const context = vm.createContext(
    Object.assign(
      {},
      {
        module: { exports },
        exports,
        URL: ImportUrl,
        __webpack_public_path__: publicPath,
      },
    ),
  );

  const syntheticDefaultExport = async (path) => {
    loaderContext.addDependency(path);
    const exports = await import(path);
    const loaded = new vm.SyntheticModule(
      ["default"],
      function () {
        this.setExport("default", exports.default);
      },
      { identifier: path, context },
    );
    return cache(path, loaded);
  };

  const evalModule = async (filename, src) => {
    const module = new vm.SourceTextModule(src, {
      identifier: filename,
      context,
    });
    await module.link(async (specifier) => {
      const { loaders, relativePath, query } = splitRelativePath(specifier);
      const absolutePath = await resolveAsync(relativePath, {
        basedir: path.dirname(filename),
      });
      const cached = moduleCache.get(absolutePath);
      if (cached !== undefined) {
        return cached;
      } else {
        const ext = path.extname(absolutePath);
        if (loaders === "" && ext === ".js") {
          return await syntheticDefaultExport(absolutePath);
        } else {
          const absoluteRequest = loaders + absolutePath + query;
          const { source } = await loadModule(loaderContext, absoluteRequest);
          return evalModule(absolutePath, source);
        }
      }
    });
    return cache(filename, module);
  };

  const resultModule = await evalModule(filename, src);
  await resultModule.evaluate();
  const cssModule = resultModule.namespace.default;

  const assets = await Promise.all(
    imports.map(async (loaded) => {
      const absolutePath = await resolveAsync(loaded.path, {
        basedir: path.dirname(filename),
      });
      loaderContext.addDependency(absolutePath);
      return `import ${loaded.importName} from "${absolutePath}";`;
    }),
  );

  const cssString = cssModule.toString();

  return `
    import { css, unsafeCSS } from "lit";

    ${assets.join("\n")}
  
    export default css\`${cssString}\`;
  `;
};

function getPublicPath(options, context) {
  let publicPath = "";

  if ("publicPath" in options) {
    publicPath =
      typeof options.publicPath === "function"
        ? options.publicPath(context)
        : options.publicPath;
  } else if (
    context.options &&
    context.options.output &&
    "publicPath" in context.options.output
  ) {
    publicPath = context.options.output.publicPath;
  } else if (
    context._compilation &&
    context._compilation.outputOptions &&
    "publicPath" in context._compilation.outputOptions
  ) {
    publicPath = context._compilation.outputOptions.publicPath;
  }

  return publicPath === "auto" ? "" : publicPath;
}

export async function extractLoader(src) {
  const importNameFactory = new ImportNameFactory();

  const callback = this.async();
  const options = this.getOptions() || {};
  const publicPath = getPublicPath(options, this);

  this.cacheable();

  try {
    callback(
      null,
      await evalDependencyGraph({
        importNameFactory,
        loaderContext: this,
        src,
        filename: this.resourcePath,
        publicPath,
      }),
    );
  } catch (error) {
    callback(error);
  }
}
export default extractLoader;
