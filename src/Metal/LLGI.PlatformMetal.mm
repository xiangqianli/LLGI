
#include <TargetConditionals.h>


#import <MetalKit/MetalKit.h>

#import "../LLGI.Platform.h"
#import "LLGI.GraphicsMetal.h"
#import "LLGI.PlatformMetal.h"
#import "LLGI.RenderPassMetal.h"
#import "LLGI.TextureMetal.h"

namespace LLGI
{

struct API_AVAILABLE(ios(13.0)) PlatformMetal_Impl
{
	Window* window_;
	bool waitVSync_;

	id<MTLDevice> device;
	id<MTLCommandQueue> commandQueue;
	CAMetalLayer* layer;
	id<CAMetalDrawable> drawable = nullptr;
	NSAutoreleasePool* pool;

	PlatformMetal_Impl(Window* window, bool waitVSync) : window_(window), waitVSync_(waitVSync)
	{
		device = MTLCreateSystemDefaultDevice();
		window_ = window;
		waitVSync_ = waitVSync;

		generateLayer();

		commandQueue = [device newCommandQueue];
	}

	~PlatformMetal_Impl()
	{
		if (layer != nullptr)
		{
			[layer release];
			layer = nullptr;
		}

		if (drawable != nullptr)
		{
			[drawable release];
		}
	}

	bool newFrame()
	{
		if (!window_->OnNewFrame())
		{
			return false;
		}

		@autoreleasepool
		{
			if (drawable != nullptr)
			{
				[drawable release];
			}

			drawable = layer.nextDrawable;
			[drawable retain];
		}
		return true;
	}

	void preset()
	{
		@autoreleasepool
		{
			id<MTLCommandBuffer> commandBuffer = [commandQueue commandBuffer];
			[commandBuffer presentDrawable:drawable];
			[commandBuffer commit];
		}
	}

	void resetLayer()
	{
		if (layer != nullptr)
		{
			[layer release];
			layer = nullptr;
		}
	}

	void generateLayer()
	{
//        UIWindow *uiwindow = (UIWindow *)window_->GetNativePtr(0);
		auto frameBufferSize = window_->GetFrameBufferSize();

		layer = [CAMetalLayer layer];
		layer.device = device;
        layer.drawsAsynchronously = waitVSync_;
		layer.pixelFormat = MTLPixelFormatBGRA8Unorm;
        // tode jessicatli
//        uiwindow.maskView.layer = layer;
#if !(TARGET_OS_IPHONE) && !(TARGET_OS_SIMULATOR)
        id view =  window_->GetNSWindowAsVoidPtr();
        if ([view isKindOfClass:[UIView class]]) {
            UIView *ui = (UIView *)view;
            ui.layer = layer;
        }
#endif
		layer.drawableSize = CGSizeMake(frameBufferSize.X, frameBufferSize.Y);
		layer.framebufferOnly = false; // Enable capture (getBytes)
	}
};

PlatformMetal::PlatformMetal(Window* window, bool waitVSync)
{
    if (@available(iOS 13.0, *)) {
        impl = new PlatformMetal_Impl(window, waitVSync);
    } else {
        // Fallback on earlier versions
    }

	ringBuffers_.resize(6);
	for (size_t i = 0; i < ringBuffers_.size(); i++)
	{
		ringBuffers_[i].renderPass = CreateSharedPtr(new RenderPassMetal());
		ringBuffers_[i].renderTexture = CreateSharedPtr(new TextureMetal());
	}

	windowSize_ = window->GetWindowSize();
}

PlatformMetal::~PlatformMetal() { delete impl; }

bool PlatformMetal::NewFrame() { return impl->newFrame(); }

void PlatformMetal::Present() { impl->preset(); }

Graphics* PlatformMetal::CreateGraphics()
{
	auto ret = new GraphicsMetal();

	auto getGraphicsView = [this]() -> GraphicsView
	{
		GraphicsView view;
		view.drawable = this->impl->drawable;
		return view;
	};

	if (ret->Initialize(getGraphicsView))
	{
		return ret;
	}

	SafeRelease(ret);
	return nullptr;
}

RenderPass* PlatformMetal::GetCurrentScreen(const Color8& clearColor, bool isColorCleared, bool isDepthCleared)
{
	// delay init
	ringBuffers_[ringIndex_].renderTexture->Reset(this->impl->drawable.texture);
	auto texPtr = ringBuffers_[ringIndex_].renderTexture.get();
	ringBuffers_[ringIndex_].renderPass->UpdateRenderTarget((Texture**)&texPtr, 1, nullptr, nullptr, nullptr);

	ringBuffers_[ringIndex_].renderPass->SetClearColor(clearColor);
	ringBuffers_[ringIndex_].renderPass->SetIsColorCleared(isColorCleared);
	ringBuffers_[ringIndex_].renderPass->SetIsDepthCleared(isDepthCleared);
	return ringBuffers_[ringIndex_].renderPass.get();
}

void PlatformMetal::SetWindowSize(const Vec2I& windowSize)
{
	if (windowSize_ == windowSize)
	{
		return;
	}

	windowSize_ = windowSize;

	impl->generateLayer();
}

}
