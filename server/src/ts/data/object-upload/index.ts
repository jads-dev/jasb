import { Config } from "../../server/config";

export interface ObjectUploader {
  supported: boolean;
  upload: (
    uploader: string,
    name: string,
    stream: Buffer,
    mime: string,
    md5: string
  ) => Promise<URL>;
}

class NullObjectUploader implements ObjectUploader {
  supported = false;

  async upload(): Promise<URL> {
    throw new Error("Not supported.");
  }
}

export async function init(
  config?: Config.ObjectUpload
): Promise<ObjectUploader> {
  switch (config?.service) {
    case "oci": {
      const { OciObjectUploader } = await import("./oci");
      return new OciObjectUploader(config);
    }

    case undefined:
      return new NullObjectUploader();
  }
}

export * as ObjectUpload from ".";
