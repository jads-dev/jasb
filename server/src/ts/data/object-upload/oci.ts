import { default as OciCommon } from "oci-common";
import { default as Oci } from "oci-objectstorage";

import { Config } from "../../server/config";
import type { ObjectUploader } from ".";

export class OciObjectUploader implements ObjectUploader {
  supported = true;
  readonly config;
  readonly client;

  constructor(config: Config.OciObjectUpload) {
    this.config = config;
    this.client = new Oci.ObjectStorageClient({
      authenticationDetailsProvider:
        new OciCommon.ConfigFileAuthenticationDetailsProvider(
          config.configPath
        ),
    });
  }

  async upload(
    uploader: string,
    name: string,
    stream: Buffer,
    contentType: string,
    md5: string
  ): Promise<URL> {
    const manager = new Oci.UploadManager(this.client);
    const extensions = name.split(".").slice(1).join(".");
    const objectName = `${md5}.${extensions}`;
    await manager.upload({
      content: { stream },
      singleUpload: true,
      requestDetails: {
        namespaceName: this.config.namespace,
        bucketName: this.config.bucket,
        objectName,
        contentMD5: Buffer.from(md5, "hex").toString("base64"),
        contentType,
        opcMeta: { uploader },
        ifNoneMatch: "*",
      },
    });
    return new URL(objectName, this.config.baseUrl);
  }
}
