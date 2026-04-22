import type { Loader } from 'astro/loaders';
import { z } from 'astro/zod';

interface CloudinarySearchLoaderOptions {
  folder: string;
  limit?: number;
}

const resourceSchema = z.object({
  asset_id: z.string(),
  public_id: z.string(),
  asset_folder: z.string(),
  display_name: z.string().optional(),
  format: z.string(),
  version: z.number(),
  resource_type: z.string(),
  type: z.string(),
  created_at: z.string(),
  bytes: z.number(),
  width: z.number(),
  height: z.number(),
  secure_url: z.string(),
  url: z.string(),
}).passthrough();

export function cloudinarySearchLoader(options: CloudinarySearchLoaderOptions): Loader {
  const { folder, limit = 500 } = options;

  return {
    name: 'cloudinary-search-loader',
    load: async ({ store, logger, generateDigest }) => {
      const cloudName = import.meta.env.PUBLIC_CLOUDINARY_CLOUD_NAME;
      const apiKey = import.meta.env.PUBLIC_CLOUDINARY_API_KEY;
      const apiSecret = import.meta.env.CLOUDINARY_API_SECRET;

      if (!cloudName || !apiKey || !apiSecret) {
        throw new Error('Missing Cloudinary credentials in .env');
      }

      logger.info('Loading photos from Cloudinary via Search API');

      let allResources: any[] = [];
      let nextCursor: string | undefined;

      while (allResources.length < limit) {
        const body: any = {
          expression: `folder:${folder}/*`,
          max_results: Math.min(100, limit - allResources.length),
          sort_by: [{ created_at: 'desc' }],
        };

        if (nextCursor) {
          body.next_cursor = nextCursor;
        }

        const response = await fetch(
          `https://api.cloudinary.com/v1_1/${cloudName}/resources/search`,
          {
            method: 'POST',
            headers: {
              Authorization: 'Basic ' + btoa(`${apiKey}:${apiSecret}`),
              'Content-Type': 'application/json',
            },
            body: JSON.stringify(body),
          }
        );

        if (!response.ok) {
          throw new Error(`Cloudinary Search API error: ${response.statusText}`);
        }

        const data = await response.json();
        allResources = [...allResources, ...data.resources];
        nextCursor = data.next_cursor;

        if (!nextCursor) break;
      }

      logger.info(`Loaded ${allResources.length} photos`);

      for (const resource of allResources) {
        store.set({
          id: resource.public_id,
          data: resource,
          digest: generateDigest(resource),
        });
      }
    },
    schema: resourceSchema,
  };
}
