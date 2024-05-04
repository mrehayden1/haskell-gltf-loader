module Text.GLTF.Loader.Internal.AdapterSpec (spec) where

import Text.GLTF.Loader.Gltf
import Text.GLTF.Loader.Internal.Adapter
import Text.GLTF.Loader.Internal.BufferAccessor
import Text.GLTF.Loader.Internal.MonadAdapter
import Text.GLTF.Loader.Test.MkGltf

import qualified Codec.GlTF.Accessor as Accessor
import qualified Codec.GlTF.BufferView as BufferView
import qualified Codec.GlTF.Image as Image
import qualified Codec.GlTF.Material as Material
import qualified Codec.GlTF.Mesh as Mesh
import qualified Codec.GlTF.Node as Node
import qualified Codec.GlTF.Scene as Scene
import qualified Codec.GlTF.Texture as Texture
import qualified Codec.GlTF.URI as URI
import qualified Data.HashMap.Strict as HashMap
import Linear
import RIO
import Test.Hspec

spec :: Spec
spec = do
  let codecGltf = mkCodecGltf
      codecMeshPrimitive = mkCodecMeshPrimitive

  describe "runAdapter" $ do
    it "Runs a basic GlTF adapter" $ do
      buffers' <- buffers
      images' <- images

      runAdapter codecGltf buffers' images' `shouldBe` loaderGltf

  describe "adaptGltf" $ do
    it "Adapts a basic GlTF" $ do
      env' <- env
      runReader adaptGltf env' `shouldBe` loaderGltf

  describe "adaptAsset" $ do
    let codecAsset = mkCodecAsset

    it "Adapts a basic asset"
      $ adaptAsset codecAsset
      `shouldBe` loaderAsset

  describe "adaptMeshes" $ do
    let codecMesh = mkCodecMesh
        codecMesh' = mkCodecMesh{Mesh.weights = Just [3.1]}

    it "Adapts a list of nodes" $ do
      env' <- env

      let meshes = Just [codecMesh, codecMesh']
          adaptedMeshes = [loaderMesh, set _meshWeights [3.1] loaderMesh]

      runReader (adaptMeshes meshes) env' `shouldBe` adaptedMeshes

    it "Adapts empty meshes" $ do
      env' <- env

      runReader (adaptMeshes (Just [])) env' `shouldBe` []
      runReader (adaptMeshes Nothing) env' `shouldBe` []

  describe "adaptMaterials" $ do
    let materials = Just [mkCodecMaterial]

    it "Adapts a list of materials" $ do
      adaptMaterials Nothing `shouldBe` []
      adaptMaterials materials `shouldBe` [loaderMaterial]

    it "Ignores PBR metallic roughness when not specified" $ do
      let materials' =
            Just
              [mkCodecMaterial{Material.pbrMetallicRoughness = Nothing}]
          adaptedMaterial = set _materialPbrMetallicRoughness Nothing loaderMaterial

      adaptMaterials materials' `shouldBe` [adaptedMaterial]

  describe "adaptNodes" $ do
    let codecNode = mkCodecNode
        codecNode' = codecNode{Node.rotation = Nothing}

    it "Adapts a list of nodes" $ do
      let nodes = Just [codecNode, codecNode']
      adaptNodes nodes `shouldBe` [loaderNode, set _nodeRotation Nothing loaderNode]

    it "Adapts empty nodes" $ do
      adaptNodes (Just []) `shouldBe` []
      adaptNodes Nothing `shouldBe` []

  describe "adaptScenes" $ do
    let scene = mkCodecScene
        scene' = scene{Scene.name = Just "Other Scene"}

    it "Adapts a list of scenes" $ do
      adaptScenes (Just [scene, scene'])
        `shouldBe` [loaderScene, set _sceneName (Just "Other Scene") loaderScene]

    it "Adapts empty scenes" $ do
      adaptScenes (Just []) `shouldBe` []
      adaptScenes Nothing `shouldBe` []

  describe "adaptImage" $ do
    let codecImage =
          Image.Image
            { uri = Nothing,
              mimeType = Just "text/jpg",
              bufferView = Just $ BufferView.BufferViewIx 6,
              name = Just "Image",
              extensions = Nothing,
              extras = Nothing
            }

    it "Adapts a BufferView image" $ do
      env' <- env
      let image = ImageBufferView (BufferView.BufferViewIx 6)

      runReader (adaptImage image codecImage) env'
        `shouldBe` Image
          { imageData = Just "imageData",
            imageMimeType = "text/jpg",
            imageName = Just "Image"
          }

    it "Adapts a URI image" $ do
      env' <- env

      let image = ImageData "imageData"
          codecImage' =
            codecImage
              { Image.uri = Just $ URI.URI "",
                Image.bufferView = Nothing
              }

      runReader (adaptImage image codecImage') env'
        `shouldBe` Image
          { imageData = Just "imageData",
            imageMimeType = "text/jpg",
            imageName = Just "Image"
          }

    it "Fails when mimeType is Nothing" $ do
      env' <- env

      let image = ImageData "imageData"
          codecImage' = codecImage{Image.mimeType = Nothing}

      -- evaluate (error "") `shouldThrow` anyErrorCall
      evaluate (runReader (adaptImage image codecImage') env') `shouldThrow` anyErrorCall

  describe "adaptMesh" $ do
    let codecMesh = mkCodecMesh
        codecMesh' = mkCodecMesh{Mesh.weights = Nothing}
        codecMesh'' = mkCodecMesh{Mesh.weights = Just []}

    it "Adapts a basic mesh" $ do
      env' <- env
      runReader (adaptMesh codecMesh) env' `shouldBe` loaderMesh

    it "Adapts empty weights" $ do
      env' <- env
      let meshEmptyWeight = set _meshWeights [] loaderMesh

      runReader (adaptMesh codecMesh') env' `shouldBe` meshEmptyWeight
      runReader (adaptMesh codecMesh'') env' `shouldBe` meshEmptyWeight

  describe "adaptNode" $ do
    it "Adapts a basic node" $ do
      adaptNode mkCodecNode `shouldBe` loaderNode

    it "Adapts empty weights" $ do
      let nodeEmptyWeight = set _nodeWeights [] loaderNode
          codecNodeEmpty = mkCodecNode{Node.weights = Nothing}
          codecNodeNothing = mkCodecNode{Node.weights = Just []}

      adaptNode codecNodeNothing `shouldBe` nodeEmptyWeight
      adaptNode codecNodeEmpty `shouldBe` nodeEmptyWeight

    it "Adapts empty children" $ do
      let nodeEmptyChildren = set _nodeChildren [] loaderNode
          codecNodeNothing = mkCodecNode{Node.children = Nothing}
          codecNodeEmpty = mkCodecNode{Node.children = Just []}

      adaptNode codecNodeNothing `shouldBe` nodeEmptyChildren
      adaptNode codecNodeEmpty `shouldBe` nodeEmptyChildren

  describe "adaptScene" $ do
    it "Adapts a basic node" $ do
      adaptScene mkCodecScene `shouldBe` loaderScene

    it "Adapts empty nodes" $ do
      let sceneEmptyNode = set _sceneNodes [] loaderScene
          codecSceneEmpty = mkCodecScene{Scene.nodes = Nothing}
          codecSceneNothing = mkCodecScene{Scene.nodes = Just []}

      adaptScene codecSceneEmpty `shouldBe` sceneEmptyNode
      adaptScene codecSceneNothing `shouldBe` sceneEmptyNode

  describe "adaptTexture" $ do
    it "Adapts simple textures" $ do
      adaptTexture mkCodecTexture `shouldBe` loaderTexture

    it "Returns Nothing fields unchanged" $ do
      let texture =
            mkCodecTexture
              { Texture.sampler = Nothing,
                Texture.source = Nothing
              }

          expectedResult =
            loaderTexture
              & _textureSamplerId
              .~ Nothing
                & _textureSourceId
              .~ Nothing

      adaptTexture texture `shouldBe` expectedResult

  describe "adaptAlphaMode" $ do
    it "Adapts all expected modes" $ do
      adaptAlphaMode Material.BLEND `shouldBe` Blend
      adaptAlphaMode Material.MASK `shouldBe` Mask
      adaptAlphaMode Material.OPAQUE `shouldBe` Opaque
      evaluate (adaptAlphaMode $ Material.MaterialAlphaMode "???")
        `shouldThrow` anyErrorCall

  describe "adaptMeshPrimitives" $ do
    let codecMeshPrimitive' =
          mkCodecMeshPrimitive
            { Mesh.mode = Mesh.MeshPrimitiveMode 0
            }

    it "adapts a list of primitives" $ do
      env' <- env
      let primitives = [codecMeshPrimitive, codecMeshPrimitive']
          expectedResult =
            [ loaderMeshPrimitive,
              set _meshPrimitiveMode Points loaderMeshPrimitive
            ]

      runReader (adaptMeshPrimitives primitives) env' `shouldBe` expectedResult

  describe "adaptMeshPrimitive" $ do
    it "adapts a basic primitive" $ do
      env' <- env
      runReader (adaptMeshPrimitive codecMeshPrimitive) env' `shouldBe` loaderMeshPrimitive

    it "ignores indices when unspecified" $ do
      env' <- env

      let codecMeshPrimitive' =
            mkCodecMeshPrimitive
              { Mesh.indices = Nothing
              }
          loaderMeshPrimitive' = loaderMeshPrimitive & _meshPrimitiveIndices .~ []

      runReader (adaptMeshPrimitive codecMeshPrimitive') env' `shouldBe` loaderMeshPrimitive'

    it "ignores material when unspecified" $ do
      env' <- env

      let codecMeshPrimitive' =
            mkCodecMeshPrimitive
              { Mesh.material = Nothing
              }
          loaderMeshPrimitive' = loaderMeshPrimitive & _meshPrimitiveMaterial .~ Nothing

      runReader (adaptMeshPrimitive codecMeshPrimitive') env'
        `shouldBe` loaderMeshPrimitive'

    it "adapts vertex colors" $ do
      env' <- env

      let codecMeshPrimitive' =
            mkCodecMeshPrimitive
              { Mesh.attributes =
                  HashMap.insert
                    attributeColors
                    (Accessor.AccessorIx 5)
                    (Mesh.attributes mkCodecMeshPrimitive)
              }
          loaderMeshPrimitive' = loaderMeshPrimitive & _meshPrimitiveColors .~ [0, 0.2, 0.6, 1]

      runReader (adaptMeshPrimitive codecMeshPrimitive') env' `shouldBe` loaderMeshPrimitive'

  describe "adaptMeshPrimitiveMode"
    $ it "Adapts all expected modes"
    $ do
      adaptMeshPrimitiveMode Mesh.POINTS `shouldBe` Points
      adaptMeshPrimitiveMode Mesh.LINES `shouldBe` Lines
      adaptMeshPrimitiveMode Mesh.LINE_LOOP `shouldBe` LineLoop
      adaptMeshPrimitiveMode Mesh.LINE_STRIP `shouldBe` LineStrip
      adaptMeshPrimitiveMode Mesh.TRIANGLES `shouldBe` Triangles
      adaptMeshPrimitiveMode Mesh.TRIANGLE_STRIP `shouldBe` TriangleStrip
      adaptMeshPrimitiveMode Mesh.TRIANGLE_FAN `shouldBe` TriangleFan
      evaluate (adaptMeshPrimitiveMode $ Mesh.MeshPrimitiveMode 7)
        `shouldThrow` anyErrorCall

buffers :: MonadUnliftIO io => io (Vector GltfBuffer)
buffers = loadBuffers mkCodecGltf Nothing basePath
  where
    basePath = "."

images :: MonadUnliftIO io => io (Vector GltfImageData)
images = loadImages mkCodecGltf basePath
  where
    basePath = "."

env :: MonadUnliftIO io => io AdaptEnv
env = AdaptEnv mkCodecGltf <$> buffers <*> images

loaderGltf :: Gltf
loaderGltf =
  Gltf
    { gltfAsset = loaderAsset,
      gltfImages = [loaderImage],
      gltfMaterials = [loaderMaterial],
      gltfMeshes = [loaderMesh],
      gltfNodes = [loaderNode],
      gltfSamplers = [loaderSampler],
      gltfScenes = [loaderScene],
      gltfTextures = [loaderTexture]
    }

loaderAsset :: Asset
loaderAsset =
  Asset
    { assetVersion = "version",
      assetCopyright = Just "copyright",
      assetGenerator = Just "generator",
      assetMinVersion = Just "minVersion"
    }

loaderImage :: Image
loaderImage =
  Image
    { imageData = Just "imagePayload",
      imageMimeType = "image/png",
      imageName = Just "Image"
    }

loaderMaterial :: Material
loaderMaterial =
  Material
    { materialAlphaCutoff = 1.0,
      materialAlphaMode = Opaque,
      materialDoubleSided = True,
      materialEmissiveFactor = V3 1.0 2.0 3.0,
      materialEmissiveTexture = Just loaderEmissiveTexture,
      materialName = Just "Material",
      materialNormalTexture = Just loaderNormalTexture,
      materialOcclusionTexture = Just loaderOcclusionTexture,
      materialPbrMetallicRoughness = Just loaderPbrMetallicRoughness
    }

loaderMesh :: Mesh
loaderMesh =
  Mesh
    { meshPrimitives = [loaderMeshPrimitive],
      meshWeights = [1.2],
      meshName = Just "mesh"
    }

loaderNode :: Node
loaderNode =
  Node
    { nodeChildren = [1],
      nodeMeshId = Just 5,
      nodeName = Just "node",
      nodeRotation = Just . Quaternion 4 $ V3 1 2 3,
      nodeScale = Just $ V3 5 6 7,
      nodeTranslation = Just $ V3 8 9 10,
      nodeWeights = [11, 12, 13]
    }

loaderSampler :: Sampler
loaderSampler =
  Sampler
    { samplerMagFilter = Just MagLinear,
      samplerMinFilter = Just MinLinear,
      samplerName = Just "Sampler",
      samplerWrapS = ClampToEdge,
      samplerWrapT = Repeat
    }

loaderScene :: Scene
loaderScene =
  Scene
    { sceneName = Just "Scene",
      sceneNodes = [0]
    }

loaderTexture :: Texture
loaderTexture =
  Texture
    { textureName = Just "Texture",
      textureSamplerId = Just 0,
      textureSourceId = Just 0
    }

loaderPbrMetallicRoughness :: PbrMetallicRoughness
loaderPbrMetallicRoughness =
  PbrMetallicRoughness
    { pbrBaseColorFactor = V4 1.0 2.0 3.0 4.0,
      pbrBaseColorTexture = Just loaderBaseColorTexture,
      pbrMetallicFactor = 1.0,
      pbrMetallicRoughnessTexture = Just loaderMetallicRoughnessTexture,
      pbrRoughnessFactor = 2.0
    }

loaderMeshPrimitive :: MeshPrimitive
loaderMeshPrimitive =
  MeshPrimitive
    { meshPrimitiveIndices = [1 .. 4],
      meshPrimitiveMaterial = Just 1,
      meshPrimitiveMode = Triangles,
      meshPrimitiveNormals = fmap (\x -> V3 x x x) [5 .. 8],
      meshPrimitivePositions = fmap (\x -> V3 x x x) [1 .. 4],
      meshPrimitiveTangents = fmap (\x -> V4 x x x x) [13 .. 16],
      meshPrimitiveTexCoords = fmap (\x -> V2 x x) [9 .. 12],
      meshPrimitiveColors = []
    }

loaderBaseColorTexture :: TextureInfo
loaderBaseColorTexture =
  TextureInfo
    { textureId = 15,
      textureTexCoord = 10
    }

loaderMetallicRoughnessTexture :: TextureInfo
loaderMetallicRoughnessTexture =
  TextureInfo
    { textureId = 16,
      textureTexCoord = 11
    }

loaderEmissiveTexture :: TextureInfo
loaderEmissiveTexture =
  TextureInfo
    { textureId = 17,
      textureTexCoord = 12
    }

loaderNormalTexture :: NormalTextureInfo
loaderNormalTexture =
  NormalTextureInfo
    { normalTextureId = 18,
      normalTextureTexCoord = 13,
      normalTextureScale = 1
    }

loaderOcclusionTexture :: OcclusionTextureInfo
loaderOcclusionTexture =
  OcclusionTextureInfo
    { occlusionTextureId = 19,
      occlusionTextureTexCoord = 14,
      occlusionTextureStrength = 2
    }
