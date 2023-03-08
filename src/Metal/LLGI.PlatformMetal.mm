
#include <TargetConditionals.h>


#import <MetalKit/MetalKit.h>
#import <UIKit/UIKit.h>

#import "../LLGI.Platform.h"
#import "LLGI.GraphicsMetal.h"
#import "LLGI.PlatformMetal.h"
#import "LLGI.RenderPassMetal.h"
#import "LLGI.TextureMetal.h"

namespace LLGI
{

struct  PlatformMetal_Impl
{
	Window* window_;
	bool waitVSync_;

	id<MTLDevice> device;
	id<MTLCommandQueue> commandQueue;
    
	id<CAMetalDrawable> drawable = nullptr;
    // jessicatli，切换CAMetalLayer为MTKView
    MTKView *view_;
    
	PlatformMetal_Impl(Window* window, bool waitVSync) : window_(window), waitVSync_(waitVSync)
	{
		device = MTLCreateSystemDefaultDevice();
		window_ = window;
		waitVSync_ = waitVSync;

		commandQueue = [device newCommandQueue];
	}
    
    PlatformMetal_Impl(Window* window, bool waitVSync, MTKView *view) : PlatformMetal_Impl(window, waitVSync)
    {
        view_ = view;
    }

	~PlatformMetal_Impl()
	{

		if (drawable != nullptr)
		{
			[drawable release];
		}
        [view_ releaseDrawables];
	}

	bool newFrame()
	{
		if (!window_->OnNewFrame())
		{
			return false;
		}
        
        drawable = view_.currentDrawable;
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

	}

	void generateLayer()
	{
        
	}
    
};

PlatformMetal::PlatformMetal(Window* window, bool waitVSync)
{
    impl = new PlatformMetal_Impl(window, waitVSync);

	ringBuffers_.resize(6);
	for (size_t i = 0; i < ringBuffers_.size(); i++)
	{
		ringBuffers_[i].renderPass = CreateSharedPtr(new RenderPassMetal());
		ringBuffers_[i].renderTexture = CreateSharedPtr(new TextureMetal());
	}

	windowSize_ = window->GetWindowSize();
}

PlatformMetal::PlatformMetal(Window* window, bool waitVSync, void * view) {
    impl = new PlatformMetal_Impl(window, waitVSync, (MTKView *)view);

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
