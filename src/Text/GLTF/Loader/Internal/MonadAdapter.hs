module Text.GLTF.Loader.Internal.MonadAdapter
  ( Adapter (),
    AdaptEnv (..),
    getGltf,
    getBuffers,
    getImages,
  ) where

import Text.GLTF.Loader.Internal.BufferAccessor

import qualified Codec.GlTF as GlTF
import RIO

type Adapter = Reader AdaptEnv

data AdaptEnv = AdaptEnv
  { asGltf :: GlTF.GlTF,
    asBuffers :: Vector GltfBuffer,
    asImages :: Vector GltfImageData
  }

getGltf :: Reader AdaptEnv GlTF.GlTF
getGltf = asks asGltf

getBuffers :: Reader AdaptEnv (Vector GltfBuffer)
getBuffers = asks asBuffers

getImages :: Reader AdaptEnv (Vector GltfImageData)
getImages = asks asImages
